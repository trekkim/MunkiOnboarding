// ContentView.swift
// MunkiOnboarding

import SwiftUI

struct ContentView: View {
    @Environment(MunkiMonitor.self) private var monitor

    var body: some View {
        Group {
            switch monitor.phase {
            case .welcome:
                WelcomeView()
                    .transition(.opacity)
            case .optionalSelection:
                OptionalSelectionView()
                    .transition(.opacity)
            case .provisioning:
                ProvisioningView()
                    .transition(.opacity)
            case .complete:
                CompletionView()
                    .transition(.opacity)
            }
        }
        .frame(width: 900, height: 660)
        .background(Color(nsColor: .onboardingBackground))
        .animation(.easeInOut(duration: 0.3), value: monitor.phase)
    }
}
