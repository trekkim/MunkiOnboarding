// OnboardingGuard.swift
// MunkiOnboarding

import Foundation

enum OnboardingGuard {

    private static let sentinelPath = "/Users/Shared/.MunkiOnboardingComplete"
    private static let launchAgentLabel = "com.trendmicro.MunkiOnboarding"
    private static let launchAgentPlist = "/Library/LaunchAgents/\(launchAgentLabel).plist"

    // MARK: - Sentinel

    static func isComplete() -> Bool {
        FileManager.default.fileExists(atPath: sentinelPath)
    }

    static func markComplete() {
        FileManager.default.createFile(atPath: sentinelPath, contents: nil, attributes: nil)
    }

    // MARK: - LaunchAgent cleanup

    static func disableLaunchAgent() {
        let uid = getuid()

        // Unload from current session (non-blocking, best effort)
        run("/bin/launchctl", ["bootout", "gui/\(uid)/\(launchAgentLabel)"])

        // Disable for all future logins for this user
        run("/bin/launchctl", ["disable", "gui/\(uid)/\(launchAgentLabel)"])
    }

    // MARK: - Private

    private static func run(_ executable: String, _ args: [String]) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: executable)
        proc.arguments = args
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError  = FileHandle.nullDevice
        try? proc.run()
        // Non-blocking — we're about to log out anyway
    }
}
