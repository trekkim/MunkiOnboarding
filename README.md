# MunkiOnboarding

A native Swift/SwiftUI macOS onboarding agent deployed during MDM zero-touch enrollment. It guides the user through the Munki installation process in real time, allows optional software selection, and ends with a Logout button for FileVault activation.

---

## Background & Problem Statement

### The problem with zero-touch enrollment

Zero-touch MDM enrollment is great for IT teams — a new Mac arrives, the user powers it on, and everything installs automatically. But from the user's perspective, it's a black box. The screen shows a spinning cursor, nothing appears to happen, and depending on the software catalogue it can take 30–60 minutes. Users don't know if the Mac is working, stuck, or waiting for them to do something. Support tickets follow.

### Existing tools and the gap

Tools like **DEPNotify** and **Erik Gomez's Hello** are great and widely used in the Mac admin community. For our specific needs and deployment setup, they have their limits — which led us to build something tailored to how we use Munki.

### Why MunkiOnboarding

The goal was simple: build something that **actually listens to Munki** and shows the user what is really happening.

MunkiOnboarding connects directly to Munki's own data sources:

- **`InstallInfo.plist`** — the source of truth for what Munki plans to install, and what it has completed
- **DistributedNotificationCenter** — Munki broadcasts live status updates (message, detail, percent complete, item name) during every install operation
- **Plist polling** — reads `InstallInfo.plist` every 2 seconds as a reliable ground truth for per-item completion, independent of notification matching

This means every status shown to the user — pending, downloading, installing, installed, failed — comes directly from Munki in real time. No scripting, no estimates, no hardcoded app lists.

### Where it fits in a zero-touch flow

MunkiOnboarding does **not** install Munki or trigger the enrollment process. It is deployed as a PKG alongside your existing zero-touch toolchain (InstallApplications, MDM, etc.). Munki is already running when MunkiOnboarding launches. The app surfaces what Munki is doing in a native window and gets out of the way when it's done.

```
MDM enrollment
    └── InstallApplications
            ├── Munki              ← does the actual software installation
            └── MunkiOnboarding    ← shows the user what Munki is doing
                    ├── Provisioning  (real-time install progress)
                    ├── Optional Software  (user picks additional apps)
                    └── Completion  (Log Out → FileVault activation)
```

### What MunkiOnboarding provides

| | MunkiOnboarding |
|---|---|
| Install progress | Live from Munki |
| Per-app status | Real-time per-item state |
| Error visibility | Automatic from `problem_items` |
| Optional software | Built-in, writes to SelfServeManifest |
| Branding | Configurable via plist + custom.zip |

---

## Requirements

- macOS 15 or later
- Munki 6+ installed on the Mac
- Munki software repository accessible to the Mac

---

## App Flow

```
Welcome  →  Provisioning  →  Optional Software  →  Completion → Log Out
```

| Screen | Description |
|--------|-------------|
| **Welcome** | Branding, feature highlights, auto-advances after 10 seconds |
| **Provisioning** | Real-time list of apps being installed, progress bar, per-item status |
| **Optional Software** | User selects additional software; written to `SelfServeManifest` for the next Munki run |
| **Completion** | Success screen with FileVault note and Log Out button |

---

## Installation

### 1. Build the app

```sh
# Archive in Xcode → Product → Archive → Distribute App → Copy App
# Place the exported MunkiOnboarding.app into pkg/payload/Applications/

xcodebuild -project MunkiOnboarding.xcodeproj \
  -scheme MunkiOnboarding \
  -configuration Release \
  -archivePath build/MunkiOnboarding.xcarchive archive
```

### 2. Build the PKG with munkipkg

```sh
# Install munkipkg if needed
pip3 install munkipkg

# Copy app into payload
cp -R build/export/MunkiOnboarding.app pkg/payload/Applications/

# Build signed pkg
munkipkg pkg
# → pkg/build/TrendAI-MunkiOnboarding-1.0.pkg
```

The PKG installs:
- `/Applications/MunkiOnboarding.app`
- `/Library/LaunchAgents/com.trendmicro.MunkiOnboarding.plist`

The `postinstall` script sets correct permissions and bootstraps the LaunchAgent into the current user session (or waits for next login).

### 3. Deploy via MDM / InstallApplications

Upload the PKG to your Munki repo or MDM and deploy it as part of the zero-touch enrollment flow. The app launches automatically after user login via the LaunchAgent.

---

## One-time run protection

MunkiOnboarding is designed to run **once per machine**. After the user clicks "Log Out":

1. A sentinel file is created at `/Users/Shared/.MunkiOnboardingComplete`
2. The LaunchAgent is disabled via `launchctl disable gui/<uid>/com.trendmicro.MunkiOnboarding`

On every subsequent launch, the app checks for the sentinel file and exits immediately if found. To re-run onboarding on the same machine (e.g. for testing), delete the sentinel file:

```sh
sudo rm /Users/Shared/.MunkiOnboardingComplete
```

---

## Munki Server Setup

### Required: client manifest

MunkiOnboarding reads the client's assigned Munki manifest for the list of managed installs. No additional manifest is required for basic functionality.

### Optional: restrict optional software

By default, **all** `optional_installs` from `InstallInfo.plist` are shown on the Optional Software screen. To show only a curated subset, create a manifest named **`MunkiOnboarding`** in your Munki repo:

```
munkirepo/manifests/MunkiOnboarding
```

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" ...>
<plist version="1.0">
<dict>
    <key>optional_installs</key>
    <array>
        <string>GoogleChrome</string>
        <string>Slack</string>
        <string>zoom</string>
    </array>
</dict>
</plist>
```

Only items whose names appear in this manifest will be shown. If the manifest does not exist or is unreachable, all `optional_installs` are shown.

### App icons in Provisioning view

MunkiOnboarding looks for app icons in this order:

1. `/Library/Managed Installs/icons/<ItemName>.png` — standard Munki icon store (populated automatically by Munki)
2. `onboarding/icons/<ItemName>.png` inside `custom.zip` — see Branding section below
3. Coloured placeholder with the item's initial letter

---

## Branding & Configuration

Branding is loaded from two sources in priority order:

### Priority 1 — Munki `custom.zip`

Place an `onboarding/` subfolder inside Munki's `client_resources/custom.zip`:

```
custom.zip
└── onboarding/
    ├── branding.plist      ← configuration
    ├── logo-dark.png       ← logo for Dark Mode (optional)
    ├── logo-light.png      ← logo for Light Mode (optional)
    └── icons/              ← app icons fallback (optional)
        ├── Slack.png
        └── zoom.png
```

Munki downloads `custom.zip` to `/Library/Managed Installs/client_resources/custom.zip` automatically. MunkiOnboarding extracts the `onboarding/` subfolder on each launch.

### Priority 2 — Local folder (PKG or MDM)

Deploy a folder to `/Library/MunkiOnboarding/` with the same structure:

```
/Library/MunkiOnboarding/
├── branding.plist
├── logo-dark.png
├── logo-light.png
└── icons/
```

If neither source is found, built-in defaults are used.

---

## branding.plist Reference

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>

    <!-- ── Welcome screen ──────────────────────────────────────── -->
    <key>WelcomeTitle</key>
    <string>Welcome to Your New Mac</string>

    <key>WelcomeSubtitle</key>
    <string>We're setting up your Mac with everything you need.
This process takes a few minutes — please stay connected to the internet.</string>

    <!-- Up to 3 feature rows. icon = SF Symbol name. -->
    <key>WelcomeFeatures</key>
    <array>
        <dict>
            <key>icon</key><string>shippingbox.fill</string>
            <key>text</key><string>Software installed automatically via Munki</string>
        </dict>
        <dict>
            <key>icon</key><string>person.badge.shield.checkmark</string>
            <key>text</key><string>Security tools configured for your region</string>
        </dict>
        <dict>
            <key>icon</key><string>lock.shield.fill</string>
            <key>text</key><string>FileVault encryption activated at first login</string>
        </dict>
    </array>

    <key>WelcomeButtonText</key>
    <string>Get Started</string>

    <!-- ── Provisioning screen ─────────────────────────────────── -->
    <key>ProvisioningTitle</key>
    <string>Setting Up Your Mac</string>

    <!-- ── Optional software screen ───────────────────────────── -->
    <key>OptionalTitle</key>
    <string>Optional Software</string>

    <key>OptionalSubtitle</key>
    <string>Select any additional software you'd like installed on your Mac.
Selected apps will be installed automatically during the next Munki run.</string>

    <!-- ── Completion screen ───────────────────────────────────── -->
    <key>CompletionTitle</key>
    <string>Setup Complete</string>

    <key>CompletionSubtitle</key>
    <string>Your Mac is ready to use.</string>

    <key>CompletionFileVaultNote</key>
    <string>To activate FileVault encryption, log out and log back in.
Your Mac will complete encryption in the background.</string>

    <key>CompletionLogoutText</key>
    <string>Log Out</string>

    <!-- ── Window behaviour ────────────────────────────────────── -->
    <!-- false = fixed center (recommended for enrollment)         -->
    <!-- true  = user can drag the window                          -->
    <key>WindowMovable</key>
    <false/>

    <!-- ── Logos ──────────────────────────────────────────────── -->
    <!-- PNG filenames relative to the branding folder.            -->
    <!-- If omitted, the built-in Trend Micro logo is used.        -->
    <key>LogoDarkFilename</key>
    <string>logo-dark.png</string>

    <key>LogoLightFilename</key>
    <string>logo-light.png</string>

</dict>
</plist>
```

### Key reference

| Key | Type | Default | Description |
|-----|------|---------|-------------|
| `WelcomeTitle` | String | `"Welcome to Your New Mac"` | Large title on welcome screen |
| `WelcomeSubtitle` | String | *(see above)* | Subtitle below title |
| `WelcomeFeatures` | Array of Dict | *(3 rows)* | Feature rows; each dict has `icon` (SF Symbol) and `text`. Max 3. |
| `WelcomeButtonText` | String | `"Get Started"` | Primary button label |
| `ProvisioningTitle` | String | `"Setting Up Your Mac"` | Header on provisioning screen |
| `OptionalTitle` | String | `"Optional Software"` | Title on optional software screen |
| `OptionalSubtitle` | String | *(see above)* | Subtitle on optional software screen |
| `CompletionTitle` | String | `"Setup Complete"` | Title on completion screen |
| `CompletionSubtitle` | String | `"Your Mac is ready to use."` | Subtitle on completion screen |
| `CompletionFileVaultNote` | String | *(see above)* | FileVault explanation text |
| `CompletionLogoutText` | String | `"Log Out"` | Logout button label |
| `WindowMovable` | Boolean | `false` | Allow user to drag the window |
| `LogoDarkFilename` | String | *(built-in)* | PNG filename for Dark Mode logo |
| `LogoLightFilename` | String | *(built-in)* | PNG filename for Light Mode logo |

---

## Logo guidelines

| Property | Recommended size | Format |
|----------|-----------------|--------|
| `LogoDarkFilename` | 400 × 120 px (2× = 800 × 240) | PNG, transparent background, white/light artwork |
| `LogoLightFilename` | 400 × 120 px (2× = 800 × 240) | PNG, transparent background, dark artwork |

Provide both variants. The app automatically selects the correct one based on the system appearance.

---

## Technical details

| Property | Value |
|----------|-------|
| Bundle ID | `com.trendmicro.MunkiOnboarding` |
| Minimum macOS | 15.0 |
| App Sandbox | No (reads `/Library/Managed Installs/`, writes `/Users/Shared/`) |
| Dock icon | Hidden (`LSUIElement = true`) |
| Window | 900 × 660 pt, floating level, fixed center by default |
| Sentinel file | `/Users/Shared/.MunkiOnboardingComplete` |
| LaunchAgent | `/Library/LaunchAgents/com.trendmicro.MunkiOnboarding.plist` |
| Branding — Munki source | `/Library/Managed Installs/client_resources/custom.zip` → `onboarding/` |
| Branding — local fallback | `/Library/MunkiOnboarding/` |
| Munki optional filter manifest | `/Library/Managed Installs/manifests/MunkiOnboarding` |

---

## Troubleshooting

**App launches again after logout / restart**
Delete the sentinel file and check the LaunchAgent is disabled:
```sh
sudo rm /Users/Shared/.MunkiOnboardingComplete
launchctl enable gui/$(id -u)/com.trendmicro.MunkiOnboarding
```

**Branding not loading**
Verify `custom.zip` exists and contains an `onboarding/branding.plist`:
```sh
unzip -l /Library/Managed\ Installs/client_resources/custom.zip | grep onboarding
```
Or check the fallback path: `ls /Library/MunkiOnboarding/`

**Optional software screen is empty**
Either `optional_installs` in `InstallInfo.plist` is empty, or the `MunkiOnboarding` manifest exists but lists no items that match `InstallInfo.plist`.

**App icons not showing**
Check `/Library/Managed Installs/icons/<ItemName>.png`. The filename must match the Munki item `name` field exactly (case-sensitive).
