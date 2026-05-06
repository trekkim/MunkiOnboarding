// LogoutHelper.swift
// MunkiOnboarding
// Exact pattern from MSC munki.swift logoutNow()

import Foundation

enum LogoutHelper {
    static func logout() {
        OnboardingGuard.disableLaunchAgent()
        // "ignoring application responses" prevents hanging if loginwindow is slow.
        let script = """
        ignoring application responses
            tell application "loginwindow"
                \u{00AB}event aevtrlgo\u{00BB}
            end tell
        end ignoring
        """
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        proc.arguments = ["-e", script]
        try? proc.run()
        // Do NOT waitUntilExit — the logout event terminates this process
    }
}
