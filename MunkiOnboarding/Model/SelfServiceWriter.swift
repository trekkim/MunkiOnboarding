// SelfServiceWriter.swift
// MunkiOnboarding
// Writes user's optional install selections to the Munki SelfServeManifest.
// Pattern taken from MSC SelfService.swift and munki.swift.

import Foundation

private let kWritablePath = "/Users/Shared/.SelfServeManifest"
private let kInstallRequestName = "com.googlecode.munki.managedsoftwareupdate.installrequest"

enum SelfServiceWriter {

    // Read existing managed_installs from the staging manifest (if any)
    static func readExistingInstalls() -> Set<String> {
        guard let dict = try? PlistIO.read(kWritablePath),
              let installs = dict["managed_installs"] as? [String] else {
            return []
        }
        return Set(installs)
    }

    // Write install/uninstall choices to /Users/Shared/.SelfServeManifest.
    // The Munki daemon promotes this to the system path on its next run.
    static func write(installs: [String], uninstalls: [String]) {
        let dict: [String: Any] = [
            "managed_installs": installs,
            "managed_uninstalls": uninstalls
        ]
        try? PlistIO.write(dict, to: kWritablePath)
    }

    // Post a DistributedNotification for each newly selected item.
    // This signals a running Munki that a self-service request arrived.
    static func postInstallRequest(item: MunkiItem) {
        let userInfo: [String: Any] = [
            "event": "install",
            "name": item.name,
            "version": item.version
        ]
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name(kInstallRequestName),
            object: nil,
            userInfo: userInfo,
            options: [.deliverImmediately, .postToAllSessions]
        )
    }
}
