// BrandingLoader.swift
// MunkiOnboarding

import Foundation

enum BrandingLoader {

    // Primary: onboarding/ subfolder inside Munki's custom.zip
    private static let zipPath      = "/Library/Managed Installs/client_resources/custom.zip"
    private static let extractPath  = "/tmp/com.trendmicro.MunkiOnboarding-branding"

    // Fallback: local folder deployed via PKG or MDM
    private static let fallbackPath = "/Library/MunkiOnboarding"

    static func load() -> BrandingConfig {
        if let config = loadFromZip()            { return config }
        if let config = loadFromFolder(fallbackPath) { return config }
        return BrandingConfig()
    }

    // MARK: - Load from custom.zip → onboarding/

    private static func loadFromZip() -> BrandingConfig? {
        guard FileManager.default.fileExists(atPath: zipPath) else { return nil }

        // Extract only the onboarding/ subfolder to avoid touching MSC files
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        proc.arguments = ["-o", zipPath, "onboarding/*", "-d", extractPath]
        proc.standardOutput = Pipe()
        proc.standardError  = Pipe()
        try? proc.run()
        proc.waitUntilExit()

        let folderPath = (extractPath as NSString).appendingPathComponent("onboarding")
        return loadFromFolder(folderPath)
    }

    // MARK: - Load from folder

    private static func loadFromFolder(_ path: String) -> BrandingConfig? {
        let plistPath = (path as NSString).appendingPathComponent("branding.plist")
        guard let raw = try? PlistIO.read(plistPath) else { return nil }
        let iconsPath = (path as NSString).appendingPathComponent("icons")
        let iconsExist = FileManager.default.fileExists(atPath: iconsPath)
        return BrandingConfig(from: raw, resourcesPath: path, iconsPath: iconsExist ? iconsPath : nil)
    }
}
