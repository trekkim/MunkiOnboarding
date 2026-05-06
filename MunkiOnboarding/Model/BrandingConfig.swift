// BrandingConfig.swift
// MunkiOnboarding

import Foundation

struct FeatureItem: Sendable {
    var sfSymbol: String
    var text: String
}

struct BrandingConfig: Sendable {

    // MARK: - Welcome screen
    var welcomeTitle: String = "Welcome to Your New Mac"
    var welcomeSubtitle: String = "We're setting up your Mac with everything you need.\nThis process takes a few minutes — please stay connected to the internet."
    var welcomeFeatures: [FeatureItem] = [
        FeatureItem(sfSymbol: "shippingbox.fill",              text: "Software installed automatically via Munki"),
        FeatureItem(sfSymbol: "person.badge.shield.checkmark", text: "Security tools configured for your region"),
        FeatureItem(sfSymbol: "lock.shield.fill",              text: "FileVault encryption activated at first login"),
    ]
    var welcomeButtonText: String = "Get Started"

    // MARK: - Provisioning screen
    var provisioningTitle: String = "Setting Up Your Mac"

    // MARK: - Optional software screen
    var optionalTitle: String = "Optional Software"
    var optionalSubtitle: String = "Select any additional software you'd like installed on your Mac.\nSelected apps will be installed automatically during the next Munki run — this may take a few minutes after login."

    // MARK: - Completion screen
    var completionTitle: String = "Setup Complete"
    var completionSubtitle: String = "Your Mac is ready to use."
    var completionFileVaultNote: String = "To activate FileVault encryption, log out and log back in. Your Mac will complete encryption in the background."
    var completionLogoutText: String = "Log Out"

    // MARK: - Logos
    // Full path to PNG file, or nil → uses bundle asset LogoWelcome-Dark / LogoWelcome-Light
    var logoDarkPath: String? = nil
    var logoLightPath: String? = nil

    // MARK: - Window behaviour
    var windowMovable: Bool = false

    // MARK: - Icons fallback directory
    // Points to onboarding/icons/ inside extracted custom.zip or /Library/MunkiOnboarding/icons/
    // ItemIconView checks this after /Library/Managed Installs/icons/ fails
    var iconsDir: String? = nil

    // MARK: - Init from plist dict

    init() {}

    init(from dict: [String: Any], resourcesPath: String, iconsPath: String? = nil) {
        iconsDir = iconsPath
        welcomeTitle        = dict["WelcomeTitle"]        as? String ?? welcomeTitle
        welcomeSubtitle     = dict["WelcomeSubtitle"]     as? String ?? welcomeSubtitle
        welcomeButtonText   = dict["WelcomeButtonText"]   as? String ?? welcomeButtonText
        provisioningTitle   = dict["ProvisioningTitle"]   as? String ?? provisioningTitle
        optionalTitle       = dict["OptionalTitle"]       as? String ?? optionalTitle
        optionalSubtitle    = dict["OptionalSubtitle"]    as? String ?? optionalSubtitle
        completionTitle     = dict["CompletionTitle"]     as? String ?? completionTitle
        completionSubtitle  = dict["CompletionSubtitle"]  as? String ?? completionSubtitle
        completionFileVaultNote = dict["CompletionFileVaultNote"] as? String ?? completionFileVaultNote
        completionLogoutText    = dict["CompletionLogoutText"]    as? String ?? completionLogoutText
        windowMovable           = dict["WindowMovable"]           as? Bool   ?? windowMovable

        if let features = dict["WelcomeFeatures"] as? [[String: String]] {
            let parsed = features.compactMap { f -> FeatureItem? in
                guard let icon = f["icon"], let text = f["text"] else { return nil }
                return FeatureItem(sfSymbol: icon, text: text)
            }
            if !parsed.isEmpty { welcomeFeatures = Array(parsed.prefix(3)) }
        }

        if let dark = dict["LogoDarkFilename"] as? String {
            let path = (resourcesPath as NSString).appendingPathComponent(dark)
            if FileManager.default.fileExists(atPath: path) { logoDarkPath = path }
        }
        if let light = dict["LogoLightFilename"] as? String {
            let path = (resourcesPath as NSString).appendingPathComponent(light)
            if FileManager.default.fileExists(atPath: path) { logoLightPath = path }
        }
    }
}
