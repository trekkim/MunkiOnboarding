// AppDelegate.swift
// MunkiOnboarding

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !OnboardingGuard.isComplete() else {
            NSApp.terminate(nil)
            return
        }
        configureMainWindow()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func configureMainWindow() {
        guard let window = NSApp.windows.first else { return }

        let branding = BrandingLoader.load()

        // Hide all traffic light buttons
        window.standardWindowButton(.closeButton)?.isHidden = true
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true

        // Lock size
        window.styleMask.remove(.resizable)

        // Movable controlled by branding plist key WindowMovable (default: false)
        window.isMovable = branding.windowMovable
        window.isMovableByWindowBackground = branding.windowMovable

        // Center on screen
        window.center()

        // Stay above other windows during onboarding
        window.level = .floating

        // Activate app
        NSApp.activate(ignoringOtherApps: true)
    }
}
