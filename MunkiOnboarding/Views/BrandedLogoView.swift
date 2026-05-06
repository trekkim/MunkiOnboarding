// BrandedLogoView.swift
// MunkiOnboarding
// Renders the correct logo: from branding file path, or bundle asset, or SF Symbol fallback.

import SwiftUI
import AppKit

struct BrandedLogoView: View {
    let branding: BrandingConfig
    var height: CGFloat = 80

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        if let img = resolvedImage {
            Image(nsImage: img)
                .resizable()
                .scaledToFit()
                .frame(height: height)
        } else {
            Image(systemName: "building.2.crop.circle.fill")
                .font(.system(size: height * 0.9))
                .foregroundStyle(Color.trendRed)
                .frame(height: height)
        }
    }

    private var resolvedImage: NSImage? {
        // 1. Custom path from branding file
        let customPath = colorScheme == .dark ? branding.logoDarkPath : branding.logoLightPath
        if let path = customPath, let img = NSImage(contentsOfFile: path) {
            return img
        }
        // 2. Bundle asset
        let assetName = colorScheme == .dark ? "LogoWelcome-Dark" : "LogoWelcome-Light"
        return NSImage(named: assetName)
    }
}
