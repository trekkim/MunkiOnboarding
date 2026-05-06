// MunkiOnboardingApp.swift
// MunkiOnboarding

import SwiftUI

@main
struct MunkiOnboardingApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var monitor = MunkiMonitor()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(monitor)
                .onAppear { monitor.start() }
                .onDisappear { monitor.stop() }
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .defaultSize(width: 900, height: 660)
    }
}
