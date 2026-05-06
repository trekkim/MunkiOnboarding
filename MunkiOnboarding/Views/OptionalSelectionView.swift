// OptionalSelectionView.swift
// MunkiOnboarding

import SwiftUI

struct OptionalSelectionView: View {
    @Environment(MunkiMonitor.self) private var monitor

    private let autoAdvanceSeconds = 10
    @State private var secondsLeft = 10
    @State private var countdownTask: Task<Void, Never>? = nil
    @State private var userInteracted = false
    @State private var selectionsApplied = false

    private let bottomBarHeight: CGFloat = 72

    var body: some View {
        VStack(spacing: 0) {

            // Header
            VStack(spacing: 6) {
                Text(monitor.branding.optionalTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text(monitor.branding.optionalSubtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 48)
            .padding(.top, 36)
            .padding(.bottom, 20)

            Divider()

            // Software list
            if monitor.optionalInstalls.isEmpty {
                emptyView
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(monitor.optionalInstalls.enumerated()), id: \.element.id) { index, item in
                            OptionalItemRow(
                                item: item,
                                isSelected: monitor.optionalSelections.contains(item.name),
                                brandingIconsDir: monitor.branding.iconsDir
                            ) {
                                monitor.toggleOptional(item)
                                userInteracted = true
                                selectionsApplied = false
                                resetTimer()
                            }
                            if index < monitor.optionalInstalls.count - 1 {
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

            Divider()

            // Bottom bar — countdown lives here as trailing overlay
            bottomBar
                .frame(height: bottomBarHeight)
                .overlay(alignment: .trailing) {
                    if !userInteracted {
                        countdownBadge
                            .padding(.trailing, 32)
                    }
                }
        }
        .frame(width: 900, height: 660)
        .background(Color(nsColor: .onboardingBackground))
        .onAppear { startTimer() }
        .onDisappear { countdownTask?.cancel() }
    }

    // MARK: - Bottom bar

    private var bottomBar: some View {
        ZStack {
            // Skip — anchored left
            HStack {
                Button("Skip") { advance() }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                    .padding(.leading, 40)
                Spacer()
            }

            // Apply — always centered, grayed when nothing selected
            Button(selectionsApplied ? "Selections Applied ✓" : "Apply & Continue") {
                monitor.applyOptionalSelections()
                selectionsApplied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { advance() }
            }
            .buttonStyle(TrendButtonStyle(color: .accentColor))
            .disabled(selectionsApplied || monitor.optionalSelections.isEmpty)
        }
    }

    // MARK: - Empty state

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)
            Text("No optional software available")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Countdown badge

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

    // MARK: - Timer

    @MainActor private func startTimer() {
        secondsLeft = autoAdvanceSeconds
        countdownTask = Task { @MainActor in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled, !userInteracted else { return }
                if secondsLeft > 1 { secondsLeft -= 1 } else { advance() ; return }
            }
        }
    }

    @MainActor private func resetTimer() {
        countdownTask?.cancel()
        countdownTask = nil
    }

    @MainActor private func advance() {
        countdownTask?.cancel()
        monitor.advanceToComplete()
    }
}
