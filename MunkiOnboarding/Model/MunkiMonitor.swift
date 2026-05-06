// MunkiMonitor.swift
// MunkiOnboarding

import Foundation
import AppKit

private let kStatusUpdateName = "com.googlecode.munki.managedsoftwareupdate.statusUpdate"
private let kUpdatesChangedName = "com.googlecode.munki.managedsoftwareupdate.updateschanged"

@MainActor
@Observable
final class MunkiMonitor {

    // MARK: - Phase

    var phase: OnboardingPhase = .welcome
    var managedInstallsDone: Bool = false

    // MARK: - Branding

    var branding: BrandingConfig = BrandingConfig()

    // MARK: - Install lists (from InstallInfo.plist)

    var managedInstalls: [MunkiItem] = []   // derived from sessionItems
    var optionalInstalls: [MunkiItem] = []
    var optionalSelections: Set<String> = []

    // MARK: - Per-item state

    var installStates: [String: InstallState] = [:]

    // Session memory: accumulates all items ever seen — never cleared during a session.
    // Preserves display order (insertion order via array + dict lookup).
    private var sessionItemOrder: [String] = []
    private var sessionItemData: [String: MunkiItem] = [:]

    // MARK: - Live Munki status (from DistributedNotificationCenter)

    var statusMessage: String = "Waiting for Munki…"
    var statusDetail: String = ""
    var progressPercent: Double = -1
    var munkiIsRunning: Bool = false

    // MARK: - Private

    private var statusObserver: (any NSObjectProtocol)?
    private var updatesObserver: (any NSObjectProtocol)?
    private let watcher = InstallInfoWatcher()
    private var processTimer: Timer?
    private var pollingTimer: Timer?

    // MARK: - Lifecycle

    func start() {
        branding = BrandingLoader.load()
        loadInstallInfo()
        startFileWatcher()
        startDNCListener()
        startProcessMonitor()
    }

    func stop() {
        if let o = statusObserver  { DistributedNotificationCenter.default().removeObserver(o); statusObserver  = nil }
        if let o = updatesObserver { DistributedNotificationCenter.default().removeObserver(o); updatesObserver = nil }
        watcher.stop()
        processTimer?.invalidate()
        processTimer = nil
        stopPollingTimer()
    }

    // MARK: - Phase navigation

    func advanceToOptionalSelection() {
        loadInstallInfo()
        phase = .optionalSelection
    }

    func advanceToProvisioning() {
        phase = .provisioning
        startPollingTimer()
    }

    // MARK: - InstallInfo.plist loading

    func loadInstallInfo() {
        let path = MunkiPrefs.installInfoPath()
        guard let raw = try? PlistIO.read(path) else { return }

        let currentManaged = parseItems(raw["managed_installs"])
        let currentNames = Set(currentManaged.map { $0.name })

        // Accumulate items into session memory (insertion order preserved)
        for item in currentManaged {
            if sessionItemData[item.name] == nil {
                sessionItemOrder.append(item.name)
            }
            sessionItemData[item.name] = item
        }

        // Merge states
        var newStates: [String: InstallState] = installStates

        // Items currently in plist
        for item in currentManaged {
            if item.installed {
                newStates[item.name] = .succeeded
            } else if newStates[item.name] == nil {
                newStates[item.name] = .pending
            }
            // Never downgrade .downloading / .installing / .succeeded back to .pending
        }

        // Items we've seen before but Munki has now removed from managed_installs:
        // they completed (or were already installed). Mark as .succeeded.
        for name in sessionItemOrder where !currentNames.contains(name) {
            switch newStates[name] ?? .pending {
            case .pending, .downloading, .downloaded, .installing:
                newStates[name] = .succeeded
            default:
                break
            }
        }

        // Apply problem_items as failed (and add to session if not already there)
        if let problems = raw["problem_items"] as? [[String: Any]] {
            for p in problems {
                guard let name = p["name"] as? String else { continue }
                let note = p["note"] as? String ?? "Unknown error"
                newStates[name] = .failed(note)
                if sessionItemData[name] == nil {
                    sessionItemOrder.append(name)
                    sessionItemData[name] = MunkiItem(
                        name: name, displayName: name, version: "",
                        installerItem: "", restartAction: "None",
                        installed: false, note: note
                    )
                }
            }
        }

        // Smart resolution: Munki installs sequentially — if item at index N is .succeeded,
        // any .installing item before N must also have completed (postinstall script finished).
        for (idx, name) in sessionItemOrder.enumerated() {
            guard case .succeeded = newStates[name] ?? .pending else { continue }
            for prevName in sessionItemOrder[..<idx] {
                if case .installing = newStates[prevName] ?? .pending {
                    newStates[prevName] = .succeeded
                }
            }
        }

        // Commit new states first so managedInstalls sees the correct values
        installStates = newStates

        // Display list = all session items in discovery order
        managedInstalls = sessionItemOrder.compactMap { sessionItemData[$0] }

        // Filter optional_installs to only items listed in the MunkiOnboarding manifest.
        // Falls back to all optional_installs if the manifest is missing or unreadable.
        let allOptional = parseItems(raw["optional_installs"])
        if let allowedNames = MunkiPrefs.onboardingOptionalNames() {
            optionalInstalls = allOptional.filter { allowedNames.contains($0.name) }
        } else {
            optionalInstalls = allOptional
        }

        // Seed optional selections from existing SelfServeManifest
        if optionalSelections.isEmpty {
            optionalSelections = SelfServiceWriter.readExistingInstalls()
        }
    }

    // MARK: - File watcher

    private func startFileWatcher() {
        watcher.start(path: MunkiPrefs.installInfoPath()) { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.loadInstallInfo()
                // Munki rewrites atomically → inode changes → restart watcher
                self.watcher.stop()
                self.startFileWatcher()
            }
        }
    }

    // MARK: - Plist polling (ground truth for per-item succeeded state)

    private func startPollingTimer() {
        pollingTimer?.invalidate()
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self, self.phase == .provisioning else { return }
                self.loadInstallInfo()
                self.checkCompletion()
            }
        }
    }

    private func stopPollingTimer() {
        pollingTimer?.invalidate()
        pollingTimer = nil
    }

    // MARK: - DistributedNotificationCenter listener

    private func startDNCListener() {
        statusObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kStatusUpdateName),
            object: nil,
            queue: .main
        ) { [weak self] note in
            guard let info = note.userInfo else { return }
            let pct: Double = {
                if let d = info["percent"] as? Double { return d }
                if let i = info["percent"] as? Int    { return Double(i) }
                if let s = info["percent"] as? String, let d = Double(s) { return d }
                return -1
            }()
            let update = MunkiStatusUpdate(
                message:     info["message"] as? String ?? "",
                detail:      info["detail"] as? String ?? "",
                percent:     pct,
                stopVisible: info["stop_button_visible"] as? Bool ?? false,
                stopEnabled: info["stop_button_enabled"] as? Bool ?? false,
                command:     info["command"] as? String ?? "",
                pid:         (info["pid"] as? Int32) ?? Int32(info["pid"] as? Int ?? 0)
            )
            Task { @MainActor [weak self] in self?.applyStatusUpdate(update) }
        }

        updatesObserver = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name(kUpdatesChangedName),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in self?.loadInstallInfo() }
        }
    }

    private func applyStatusUpdate(_ u: MunkiStatusUpdate) {
        munkiIsRunning = true
        if !u.message.isEmpty { statusMessage = u.message }
        statusDetail = u.detail
        progressPercent = u.percent

        // Route to download or install tracker based on message content
        let msgLow = u.message.lowercased()
        if msgLow.contains("download") {
            updateDownloadingItem(from: u.detail)
        } else if msgLow.contains("running postinstall") {
            // "Running postinstall_script for Office 2019 Installer - EU CDN"
            // Message contains item name directly — more reliable than detail
            let suffix = u.message.components(separatedBy: " for ").dropFirst().joined(separator: " for ")
            if !suffix.isEmpty { updateInstallingItem(from: suffix) }
        } else if msgLow.contains("install") || msgLow.contains("running") || msgLow.contains("configur") {
            updateInstallingItem(from: u.detail)
        }

        switch u.command {
        case "quit":
            munkiIsRunning = false
            loadInstallInfo()
            checkCompletion()
        default:
            break
        }
    }

    private func updateDownloadingItem(from detail: String) {
        guard !detail.isEmpty else { return }
        let lowDetail = detail.lowercased()
        let allItems = sessionItemOrder.compactMap { sessionItemData[$0] }
        for item in allItems {
            guard installStates[item.name] == .pending || installStates[item.name] == nil else { continue }
            if matches(detail: lowDetail, item: item) {
                for (name, state) in installStates {
                    if case .downloading = state { installStates[name] = .downloaded }
                }
                installStates[item.name] = .downloading
                return
            }
        }
    }

    private func updateInstallingItem(from detail: String) {
        guard !detail.isEmpty else { return }
        let lowDetail = detail.lowercased()
        for item in managedInstalls {
            switch installStates[item.name] ?? .pending {
            case .pending, .downloading, .downloaded: break
            default: continue
            }
            if matches(detail: lowDetail, item: item) {
                for (name, state) in installStates {
                    if case .installing  = state { installStates[name] = .succeeded }
                    if case .downloading = state { installStates[name] = .downloaded }
                }
                installStates[item.name] = .installing
                return
            }
        }
    }

    // Tries displayName, item name, and installer filename (without extension)
    private func matches(detail: String, item: MunkiItem) -> Bool {
        if detail.contains(item.displayName.lowercased()) { return true }
        if detail.contains(item.name.lowercased()) { return true }
        let base = (item.installerItem as NSString).deletingPathExtension.lowercased()
        if !base.isEmpty && detail.contains(base) { return true }
        return false
    }

    // MARK: - Process monitor (guard against Munki dying without "quit" command)

    private func startProcessMonitor() {
        processTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor [weak self] in
                guard let self, self.munkiIsRunning else { return }
                let running = await Task.detached {
                    let proc = Process()
                    proc.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
                    proc.arguments = ["-x", "managedsoftwareupdate"]
                    let pipe = Pipe()
                    proc.standardOutput = pipe
                    proc.standardError = Pipe()
                    try? proc.run()
                    proc.waitUntilExit()
                    return !pipe.fileHandleForReading.readDataToEndOfFile().isEmpty
                }.value
                if !running {
                    self.munkiIsRunning = false
                    self.loadInstallInfo()
                    self.checkCompletion()
                }
            }
        }
    }

    // MARK: - Completion check

    private func checkCompletion() {
        guard phase == .provisioning else { return }
        let allItems = sessionItemOrder.compactMap { sessionItemData[$0] }
        guard !allItems.isEmpty else { return }
        let allDone = allItems.allSatisfy {
            switch installStates[$0.name] ?? .pending {
            case .succeeded, .failed: return true
            default: return false
            }
        }
        if allDone && !munkiIsRunning {
            stopPollingTimer()
            managedInstallsDone = true
        }
    }

    func advanceToComplete() {
        OnboardingGuard.markComplete()
        phase = .complete
    }

    // MARK: - Optional installs

    func toggleOptional(_ item: MunkiItem) {
        if optionalSelections.contains(item.name) {
            optionalSelections.remove(item.name)
        } else {
            optionalSelections.insert(item.name)
        }
    }

    func applyOptionalSelections() {
        SelfServiceWriter.write(
            installs: Array(optionalSelections),
            uninstalls: []
        )
        for name in optionalSelections {
            if let item = optionalInstalls.first(where: { $0.name == name }) {
                SelfServiceWriter.postInstallRequest(item: item)
            }
        }
    }

    // MARK: - Helpers

    private func parseItems(_ raw: Any?) -> [MunkiItem] {
        guard let arr = raw as? [[String: Any]] else { return [] }
        return arr.compactMap { dict in
            guard let name = dict["name"] as? String else { return nil }
            let rawDisplayName = dict["display_name"] as? String ?? ""
            return MunkiItem(
                name: name,
                displayName: rawDisplayName.isEmpty ? name : rawDisplayName,
                version: dict["version_to_install"] as? String ?? "",
                installerItem: dict["installer_item"] as? String ?? "",
                restartAction: dict["RestartAction"] as? String ?? "None",
                installed: dict["installed"] as? Bool ?? false,
                note: dict["note"] as? String
            )
        }
    }
}
