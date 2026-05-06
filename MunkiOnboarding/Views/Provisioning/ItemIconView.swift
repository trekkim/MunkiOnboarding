// ItemIconView.swift
// MunkiOnboarding

import SwiftUI
import AppKit

struct ItemIconView: View {
    let itemName: String
    var brandingIconsDir: String? = nil   // fallback from onboarding branding
    @State private var image: NSImage? = nil

    var body: some View {
        Group {
            if let img = image {
                Image(nsImage: img)
                    .resizable()
                    .interpolation(.high)
                    .antialiased(true)
                    .scaledToFit()
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(placeholderColor(for: itemName))
                    Text(itemName.prefix(1).uppercased())
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                }
                .frame(width: 34, height: 34)
            }
        }
        .frame(width: 48, height: 48)
        .task(id: itemName) {
            image = await loadIcon(itemName)
        }
    }

    // MARK: - Icon loading (priority order)

    private func loadIcon(_ name: String) async -> NSImage? {
        await Task.detached(priority: .utility) { [brandingIconsDir] in
            let filename = "\(name).png"

            // 1. Munki standard icon store
            let munkiPath = (MunkiPrefs.iconsDir() as NSString).appendingPathComponent(filename)
            if let img = NSImage(contentsOfFile: munkiPath) { return img }

            // 2. onboarding/icons/ from custom.zip or /Library/MunkiOnboarding/icons/
            if let dir = brandingIconsDir {
                let brandingPath = (dir as NSString).appendingPathComponent(filename)
                if let img = NSImage(contentsOfFile: brandingPath) { return img }
            }

            return nil
        }.value
    }

    // MARK: - Placeholder color

    private func placeholderColor(for name: String) -> Color {
        let palette: [Color] = [
            Color(hue: 0.58, saturation: 0.6, brightness: 0.7),
            Color(hue: 0.72, saturation: 0.5, brightness: 0.65),
            Color(hue: 0.35, saturation: 0.55, brightness: 0.6),
            Color(hue: 0.08, saturation: 0.65, brightness: 0.75),
            Color(hue: 0.5,  saturation: 0.55, brightness: 0.65),
            Color(hue: 0.95, saturation: 0.5, brightness: 0.7),
        ]
        return palette[abs(name.hashValue) % palette.count]
    }
}
