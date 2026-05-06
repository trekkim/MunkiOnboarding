// ItemRow.swift
// MunkiOnboarding

import SwiftUI

struct ItemRow: View {
    let item: MunkiItem
    let state: InstallState
    var progress: Double = -1
    var brandingIconsDir: String? = nil

    @State private var spinAngle: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            ItemIconView(itemName: item.name, brandingIconsDir: brandingIconsDir)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                if !item.version.isEmpty {
                    Text(item.version)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            stateIndicator
                .padding(.trailing, 8)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }

    // MARK: - State indicator

    @ViewBuilder
    private var stateIndicator: some View {
        switch state {
        case .pending:
            HStack(spacing: 6) {
                Circle()
                    .stroke(
                        Color.accentColor.opacity(0.7),
                        style: StrokeStyle(lineWidth: 2, dash: [4, 3])
                    )
                    .frame(width: 18, height: 18)
                Text("Pending")
                    .font(.caption)
                    .foregroundStyle(Color.accentColor.opacity(0.7))
            }

        case .downloading:
            HStack(spacing: 5) {
                Image(systemName: "arrow.down.circle")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
                Text("Downloading…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .downloaded:
            HStack(spacing: 5) {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                Text("Waiting for installation")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .installing:
            HStack(spacing: 8) {
                circularProgress
                Text("Installing…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

        case .succeeded:
            HStack(spacing: 5) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color(nsColor: .systemGreen))
                Text("Installed")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(Color(nsColor: .systemGreen))
            }

        case .failed(let note):
            HStack(spacing: 5) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.red)
                Text(note)
                    .font(.caption)
                    .foregroundStyle(Color.red)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Circular progress (fills up as install progresses)

    private var circularProgress: some View {
        ZStack {
            Circle()
                .stroke(Color(nsColor: .systemGreen).opacity(0.20), lineWidth: 2.5)
            if progress >= 0 {
                Circle()
                    .trim(from: 0, to: CGFloat(progress / 100))
                    .stroke(
                        Color(nsColor: .systemGreen),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.4), value: progress)
            } else {
                // indeterminate — spinning arc
                Circle()
                    .trim(from: 0, to: 0.25)
                    .stroke(
                        Color(nsColor: .systemGreen),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .rotationEffect(.degrees(spinAngle))
                    .onAppear {
                        withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                            spinAngle = 360
                        }
                    }
            }
        }
        .frame(width: 20, height: 20)
    }
}
