// WelcomeView.swift
// MunkiOnboarding

import SwiftUI

struct WelcomeView: View {
    @Environment(MunkiMonitor.self) private var monitor

    private let autoAdvanceSeconds = 10
    @State private var secondsLeft = 10
    @State private var countdownTask: Task<Void, Never>? = nil

    private var b: BrandingConfig { monitor.branding }

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            BrandedLogoView(branding: b, height: 80)
                .padding(.bottom, 32)

            Text(b.welcomeTitle)
                .font(.largeTitle)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text(b.welcomeSubtitle)
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top, 12)
                .padding(.horizontal, 80)

            Spacer()

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(b.welcomeFeatures.enumerated()), id: \.offset) { _, feature in
                    featureRow(icon: feature.sfSymbol, text: feature.text)
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 80)

            Spacer()

            Button(b.welcomeButtonText) {
                advance()
            }
            .buttonStyle(TrendButtonStyle(color: .accentColor))
            .padding(.bottom, 48)
        }
        .frame(width: 900, height: 660)
        .overlay(alignment: .bottomTrailing) {
            countdownBadge
                .padding(24)
        }
        .onAppear { startTimer() }
        .onDisappear { countdownTask?.cancel() }
    }

    private var countdownBadge: some View {
        ZStack {
            Circle()
                .stroke(Color.trendRed.opacity(0.12), lineWidth: 3.5)
            Circle()
                .trim(from: 0, to: CGFloat(secondsLeft) / CGFloat(autoAdvanceSeconds))
                .stroke(Color.trendRed, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: secondsLeft)
            Text("\(secondsLeft)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.trendRed)
                .monospacedDigit()
        }
        .frame(width: 30, height: 30)
    }

    @MainActor private func startTimer() {
        secondsLeft = autoAdvanceSeconds
        countdownTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                if secondsLeft > 1 { secondsLeft -= 1 } else { advance() ; return }
            }
        }
    }

    @MainActor private func advance() {
        countdownTask?.cancel()
        monitor.advanceToProvisioning()
    }

    private func featureRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(Color.accentColor)
                .frame(width: 34)
            Text(text)
                .font(.body)
        }
    }
}
