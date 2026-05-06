// MunkiPrefs.swift
// MunkiOnboarding

@preconcurrency import Foundation

enum MunkiPrefs {
    private static let bundleID = "ManagedInstalls"

    static func managedInstallDir() -> String {
        if let v = CFPreferencesCopyAppValue("ManagedInstallDir" as CFString, bundleID as CFString) as? String {
            return v
        }
        return "/Library/Managed Installs"
    }

    static func installInfoPath() -> String {
        (managedInstallDir() as NSString).appendingPathComponent("InstallInfo.plist")
    }

    static func iconsDir() -> String {
        (managedInstallDir() as NSString).appendingPathComponent("icons")
    }

    static func logsDir() -> String {
        (managedInstallDir() as NSString).appendingPathComponent("Logs")
    }

    static func onboardingManifestPath() -> String {
        (managedInstallDir() as NSString)
            .appendingPathComponent("manifests/MunkiOnboarding")
    }

    /// Returns the set of item names listed in the MunkiOnboarding manifest's
    /// optional_installs array, or nil if the manifest doesn't exist / can't be read.
    static func onboardingOptionalNames() -> Set<String>? {
        guard let raw = try? PlistIO.read(onboardingManifestPath()),
              let names = raw["optional_installs"] as? [String],
              !names.isEmpty else { return nil }
        return Set(names)
    }
}
