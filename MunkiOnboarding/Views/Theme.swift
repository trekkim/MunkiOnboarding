// Theme.swift
// MunkiOnboarding
// Trend Micro brand colors + custom button style

import SwiftUI
import AppKit

// MARK: - Colors

extension Color {
    /// Trend Micro primary red
    static let trendRed = Color(nsColor: .trendMicroRed)
}

extension NSColor {
    /// Trend Micro primary red #D70B20
    static let trendMicroRed = NSColor(
        light: NSColor(red: 0.843, green: 0.043, blue: 0.125, alpha: 1.0),
        dark:  NSColor(red: 0.900, green: 0.120, blue: 0.180, alpha: 1.0)
    )

    /// Card background — slightly elevated above window background
    static let cardBackground = NSColor(
        light: .controlBackgroundColor,
        dark: NSColor(red: 0.20, green: 0.20, blue: 0.20, alpha: 1.0)
    )

    /// Window background — off-white / near-black
    static let onboardingBackground = NSColor(
        light: NSColor(red: 0.965, green: 0.965, blue: 0.965, alpha: 1.0),
        dark:  NSColor(red: 0.118, green: 0.118, blue: 0.118, alpha: 1.0)
    )

    private convenience init(light: NSColor, dark: NSColor) {
        self.init(name: nil) { appearance in
            switch appearance.bestMatch(from: [.aqua, .darkAqua]) {
            case .darkAqua: return dark
            default:        return light
            }
        }
    }
}

// MARK: - Optional Card Style

struct OnboardingCardStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    @ViewBuilder
    func body(content: Content) -> some View {
        if colorScheme == .dark {
            content
                .background(Color(nsColor: .cardBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .shadow(color: .black.opacity(0.10), radius: 3, x: 0, y: 1)
                .shadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 4)
        } else {
            content
                .background(Color(nsColor: .cardBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.07), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 3)
        }
    }
}

// MARK: - Button Style

struct TrendButtonStyle: ButtonStyle {
    var compact: Bool = false
    var color: Color = .trendRed
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(compact ? .callout.weight(.medium) : .body.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, compact ? 16 : 32)
            .padding(.vertical, compact ? 6 : 12)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(backgroundColor(pressed: configuration.isPressed))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }

    private func backgroundColor(pressed: Bool) -> Color {
        guard isEnabled else { return Color(nsColor: .systemGray).opacity(0.4) }
        return pressed ? color.opacity(0.8) : color
    }
}
