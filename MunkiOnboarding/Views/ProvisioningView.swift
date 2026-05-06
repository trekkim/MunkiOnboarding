// ProvisioningView.swift
// MunkiOnboarding

import SwiftUI

private struct MunkiWaitingSpinner: View {
    @State private var s1: Double = 0   // outer — slow clockwise
    @State private var s2: Double = 0   // mid   — medium counter-clockwise
    @State private var s3: Double = 0   // inner — fast clockwise
    @State private var glow: Bool = false

    var body: some View {
        ZStack {
            // subtle background track
            Circle()
                .stroke(Color.accentColor.opacity(0.08), lineWidth: 2)
                .frame(width: 76, height: 76)

            // outer ring — long arc, slow
            Circle()
                .trim(from: 0.0, to: 0.60)
                .stroke(
                    Color.accentColor.opacity(0.80),
                    style: StrokeStyle(lineWidth: 4.5, lineCap: .round)
                )
                .frame(width: 76, height: 76)
                .rotationEffect(.degrees(s1))

            // middle ring — medium arc, faster, opposite direction
            Circle()
                .trim(from: 0.08, to: 0.52)
                .stroke(
                    Color.accentColor.opacity(0.50),
                    style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                )
                .frame(width: 56, height: 56)
                .rotationEffect(.degrees(s2))

            // inner ring — short arc, fastest
            Circle()
                .trim(from: 0.04, to: 0.32)
                .stroke(
                    Color.accentColor.opacity(0.35),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                )
                .frame(width: 36, height: 36)
                .rotationEffect(.degrees(s3))

            // center dot — breathes
            Circle()
                .fill(Color.accentColor.opacity(glow ? 0.85 : 0.25))
                .frame(width: 8, height: 8)
                .scaleEffect(glow ? 1.2 : 0.85)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: glow)
        }
        .onAppear {
            withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) { s1 = 360 }
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) { s2 = -360 }
            withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) { s3 = 360 }
            glow = true
        }
    }
}

struct ProvisioningView: View {
    @Environment(MunkiMonitor.self) private var monitor

    private let countdownSeconds = 15
    @State private var secondsLeft = 15
    @State private var countdownTask: Task<Void, Never>? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            headerSection
                .padding(.horizontal, 32)
                .padding(.top, 28)
                .padding(.bottom, 16)

            Divider()

            if monitor.managedInstalls.isEmpty {
                waitingView
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(monitor.managedInstalls.enumerated()), id: \.element.id) { index, item in
                            let state = monitor.installStates[item.name] ?? .pending
                            let isActive: Bool = {
                                if case .downloading = state { return true }
                                if case .installing  = state { return true }
                                return false
                            }()
                            ItemRow(
                                item: item,
                                state: state,
                                progress: isActive ? monitor.progressPercent : -1,
                                brandingIconsDir: monitor.branding.iconsDir
                            )
                            if index < monitor.managedInstalls.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .modifier(OnboardingCardStyle())
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                }
                .scrollContentBackground(.hidden)
            }

            if monitor.managedInstallsDone {
                Divider()
                completionBar
                    .frame(height: 72)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(width: 900, height: 660)
        .animation(.easeInOut(duration: 0.3), value: monitor.managedInstallsDone)
        .onChange(of: monitor.managedInstallsDone) { _, done in
            if done { startCountdown() }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monitor.branding.provisioningTitle)
                .font(.title2)
                .fontWeight(.bold)

            Text(monitor.statusMessage)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if monitor.managedInstallsDone {
                ProgressView(value: 1.0, total: 1.0)
                    .progressViewStyle(.linear)
                    .tint(Color(nsColor: .systemGreen))
            } else if monitor.progressPercent < 0 {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(Color.accentColor)
            } else {
                ProgressView(value: monitor.progressPercent, total: 100)
                    .progressViewStyle(.linear)
                    .tint(Color.accentColor)
            }

            if !monitor.statusDetail.isEmpty {
                Text(monitor.statusDetail)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Waiting state

    private var waitingView: some View {
        VStack(spacing: 20) {
            Spacer()
            MunkiWaitingSpinner()
            VStack(spacing: 6) {
                Text("Preparing installation…")
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text("Waiting for Munki to prepare the install list")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Completion bar with countdown

    private var completionBar: some View {
        ZStack {
            // Left — status message
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color(nsColor: .systemGreen))
                Text("Installation complete")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
            }
            .padding(.leading, 32)

            // Center — Continue button
            Button("Continue") {
                advance()
            }
            .buttonStyle(TrendButtonStyle(color: .accentColor))

            // Right — countdown badge, independent of button
            HStack {
                Spacer()
                countdownBadge
            }
            .padding(.trailing, 32)
        }
    }

    private var countdownBadge: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.15), lineWidth: 3)
            Circle()
                .trim(from: 0, to: CGFloat(secondsLeft) / CGFloat(countdownSeconds))
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: secondsLeft)
            Text("\(secondsLeft)")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.accentColor)
                .monospacedDigit()
        }
        .frame(width: 26, height: 26)
    }

    // MARK: - Countdown

    @MainActor private func startCountdown() {
        secondsLeft = countdownSeconds
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
        monitor.advanceToOptionalSelection()
    }
}
