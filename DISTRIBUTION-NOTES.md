# TwinKley Distribution Notes

Reference guide for distributing TwinKley as an indie macOS app.

---

## Inspiration: Successful Indie macOS Apps

| App | Stars | Website | Distribution |
|-----|-------|---------|--------------|
| [Stats](https://github.com/exelban/stats) | 35.8k | [mac-stats.com](https://mac-stats.com) | DMG + Homebrew |
| [MonitorControl](https://github.com/MonitorControl/MonitorControl) | 32.1k | [monitorcontrol.app](https://monitorcontrol.app) | DMG + Homebrew |
| [Rectangle](https://github.com/rxhanson/Rectangle) | 28.2k | [rectangleapp.com](https://rectangleapp.com) | DMG + Homebrew |

**MonitorControl** is the most similar to TwinKley (display brightness control).

### Curated Lists for Discovery
- [awesome-mac](https://github.com/jaywcjlove/awesome-mac) - General macOS apps
- [open-source-mac-os-apps](https://github.com/serhii-londar/open-source-mac-os-apps) - 47k stars
- [Menu Bar Apps](https://github.com/menubar-apps) - Menu bar specific

---

## Distribution Options

### Option 1: GitHub Releases (Free)

Simplest approach - just upload a zip or DMG to GitHub releases.

**Pros:**
- Free, immediate
- Easy updates
- Built-in download stats

**Cons:**
- Users see Gatekeeper warning without notarization
- Must right-click > Open to bypass

**What to include:**
- `TwinKley.app` in a zip or DMG
- Release notes with changelog
- SHA256 checksum (optional)

### Option 2: Notarized Distribution ($99/year)

Required for a professional, warning-free experience.

**Requirements:**
1. Apple Developer Program membership ($99/year)
2. Developer ID certificate
3. Hardened Runtime enabled
4. Notarization via `notarytool`

**Process:**
```bash
# 1. Archive and export with Developer ID signing (Xcode)
# Product > Archive > Distribute App > Developer ID

# 2. Create DMG
brew install create-dmg
create-dmg \
  --volname "TwinKley" \
  --window-pos 200 120 \
  --window-size 600 400 \
  --icon-size 100 \
  --icon "TwinKley.app" 150 190 \
  --app-drop-link 450 190 \
  TwinKley.dmg \
  TwinKley.app

# 3. Notarize the DMG
xcrun notarytool submit TwinKley.dmg \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --password "app-specific-password" \
  --wait

# 4. Staple the ticket
xcrun stapler staple TwinKley.dmg

# 5. Verify
spctl --assess --type open --context context:primary-signature -v TwinKley.dmg
# Expected: "TwinKley.dmg: accepted source=Notarized Developer ID"
```

**References:**
- [Apple Developer ID](https://developer.apple.com/developer-id/)
- [Notarizing macOS Software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [Customizing Notarization Workflow](https://developer.apple.com/documentation/security/customizing-the-notarization-workflow)

### Option 3: Homebrew Cask (After traction)

Once you have GitHub releases, submit a Homebrew cask formula.

```ruby
# Example cask formula
cask "twinkley" do
  version "1.3.0"
  sha256 "abc123..."

  url "https://github.com/username/TwinKley/releases/download/v#{version}/TwinKley.dmg"
  name "TwinKley"
  desc "Syncs keyboard backlight to display brightness"
  homepage "https://github.com/username/TwinKley"

  app "TwinKley.app"

  zap trash: [
    "~/Library/Application Support/TwinKley",
    "~/Library/Preferences/com.local.TwinKley.plist",
  ]
end
```

Submit to: https://github.com/Homebrew/homebrew-cask

---

## README Structure

Based on Stats and MonitorControl patterns:

```markdown
# TwinKley

<p align="center">
  <img src="icon.png" width="128" alt="TwinKley icon">
</p>

<p align="center">
  Syncs your Mac's keyboard backlight to display brightness.
</p>

<p align="center">
  <a href="releases"><img src="https://img.shields.io/github/downloads/user/TwinKley/total.svg" alt="downloads"></a>
  <a href="releases"><img src="https://img.shields.io/github/v/release/user/TwinKley" alt="version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/github/license/user/TwinKley" alt="license"></a>
</p>

<p align="center">
  <img src="screenshot.png" width="400" alt="Screenshot">
</p>

## Installation

### Manual
Download [TwinKley.dmg](https://github.com/user/TwinKley/releases/latest)

### Homebrew
\`\`\`bash
brew install --cask twinkley
\`\`\`

## Features

- Automatic keyboard backlight sync to display brightness
- Responds to brightness keys instantly
- Optional timed sync (configurable interval)
- Battery-aware: pauses sync on battery or low battery
- Zero idle CPU usage (event-driven, no polling)
- Tiny footprint: 108KB binary, ~11MB memory

## Requirements

macOS 12.0 (Monterey) or later

## Permissions

TwinKley requires Accessibility permission to detect brightness key presses.

System Settings > Privacy & Security > Accessibility > TwinKley

## FAQ

### How do I quit the app?
Click the menu bar icon and select "Quit TwinKley"

### Why does the keyboard brightness sometimes not match exactly?
The keyboard has discrete brightness levels (0-100) while some displays
have different ranges. TwinKley maps them proportionally.

### Does this work with external keyboards?
Only Apple keyboards with backlight are supported.

## Building from Source

\`\`\`bash
git clone https://github.com/user/TwinKley.git
cd TwinKley
./build.sh
\`\`\`

## License

MIT License - see [LICENSE](LICENSE)
```

---

## Checklist Before Release

### Repository
- [ ] Clean README with screenshot
- [ ] LICENSE file (MIT recommended)
- [ ] .gitignore for build artifacts
- [ ] Remove any sensitive/debug code

### App
- [ ] Proper app icon (already have)
- [ ] Info.plist with correct metadata
- [ ] Minimum deployment target set
- [ ] Test on clean macOS install

### Release
- [ ] Semantic versioning (v1.0.0)
- [ ] Changelog/release notes
- [ ] DMG or zip with app
- [ ] SHA256 checksum (optional)

### Growth (Later)
- [ ] Submit to awesome-mac lists
- [ ] Create Homebrew cask
- [ ] Simple landing page
- [ ] Social media announcement

---

## Resources

### Tools
- [create-dmg](https://github.com/create-dmg/create-dmg) - Beautiful DMG creation
- [Sparkle](https://sparkle-project.org/) - Auto-update framework (optional)

### Articles
- [Distributing macOS Apps Outside the App Store](https://dev.to/ajpagente/distributing-a-macos-app-outside-the-mac-app-store-433g)
- [Beyond the Sandbox](https://www.appcoda.com/distribute-macos-apps/) - AppCoda guide
- [Distributing Without Notarization](https://lapcatsoftware.com/articles/without-notarization.html) - Edge cases

### Community
- r/macapps - Reddit community
- Hacker News "Show HN" - For launches
- Product Hunt - For polished launches

---

---

## Notarization Deep Dive

### Hardened Runtime Entitlements

TwinKley will need specific entitlements for notarization. Create `TwinKley.entitlements`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <!-- Required for Accessibility API (key monitoring) -->
    <key>com.apple.security.automation.apple-events</key>
    <true/>
</dict>
</plist>
```

**Note:** TwinKley uses:
- `CGEvent` tap for keyboard monitoring (requires Accessibility permission at runtime, not entitlement)
- `IOKit` for power state (no special entitlement needed)
- Private `DisplayServices.framework` via `dlopen` (may need `com.apple.security.cs.disable-library-validation` if issues arise)

### Common Notarization Failures

| Error | Cause | Fix |
|-------|-------|-----|
| "The signature is invalid" | Signing issue | Re-sign with `codesign --force --deep --sign "Developer ID"` |
| "The executable requests the com.apple.security.get-task-allow entitlement" | Debug entitlement left in | Remove `get-task-allow` from release builds |
| "The binary uses an SDK older than 10.9" | Old deployment target | Set minimum deployment to 10.9+ |
| "The signature does not include a secure timestamp" | Missing timestamp | Add `--timestamp` to codesign |

### Storing Credentials for CI/CD

```bash
# Store credentials in keychain (one-time setup)
xcrun notarytool store-credentials "AC_PASSWORD" \
  --apple-id "your@email.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"

# Then use in scripts
xcrun notarytool submit TwinKley.dmg \
  --keychain-profile "AC_PASSWORD" \
  --wait
```

### Signature Changes Warning

From MonitorControl's experience: If you change your signing certificate (e.g., renew Developer ID), **auto-update may break**. Users on old versions won't auto-update to new signature. Document this in release notes and provide manual download links.

---

## Auto-Updates with Sparkle

[Sparkle](https://sparkle-project.org/) is the standard for macOS app auto-updates.

### Basic Setup

1. Add Sparkle via SPM:
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/sparkle-project/Sparkle", from: "2.0.0")
]
```

2. Create `appcast.xml` hosted on your server/GitHub Pages:
```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>TwinKley Updates</title>
    <item>
      <title>Version 1.3.0</title>
      <sparkle:version>1.3.0</sparkle:version>
      <sparkle:shortVersionString>1.3.0</sparkle:shortVersionString>
      <pubDate>Wed, 15 Jan 2026 12:00:00 +0000</pubDate>
      <enclosure url="https://example.com/TwinKley-1.3.0.dmg"
                 sparkle:edSignature="BASE64_SIGNATURE"
                 length="1234567"
                 type="application/octet-stream"/>
    </item>
  </channel>
</rss>
```

3. Add to Info.plist:
```xml
<key>SUFeedURL</key>
<string>https://example.com/appcast.xml</string>
```

### Sparkle Alternatives

- **Manual check**: Simple "Check for Updates" menu item that opens GitHub releases
- **GitHub API**: Query `https://api.github.com/repos/user/TwinKley/releases/latest`

Stats uses their own API (`api.mac-stats.com`) with GitHub as fallback.

---

## Privacy & Transparency

### Stats' Approach to External APIs

Stats documents all external connections in their README:
- Update check API
- Public IP lookup (for network module)
- Clear instructions for blocking if desired

**For TwinKley:** Document that the app:
- Makes NO network connections
- Stores settings locally only (`~/Library/Application Support/TwinKley/`)
- Requires Accessibility permission (explain why)

### Privacy Policy

Not strictly required for direct distribution, but good practice:

```markdown
## Privacy Policy

TwinKley does not collect, store, or transmit any personal data.

- No analytics or telemetry
- No network connections
- Settings stored locally on your Mac
- Accessibility permission used solely for detecting brightness key presses
```

---

## Accessibility Permission UX

TwinKley requires Accessibility permission for the CGEvent tap. Best practices:

### First Launch Experience

1. **Explain before prompting**: Show a dialog explaining WHY the permission is needed
2. **Deep link to settings**: `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`
3. **Check permission status**: Use `AXIsProcessTrusted()` or `AXIsProcessTrustedWithOptions()`

### Sample Permission Check

```swift
import ApplicationServices

func checkAccessibilityPermission() -> Bool {
    let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
    return AXIsProcessTrustedWithOptions(options)
}
```

### Handling Denial

- App should still launch (menu bar icon visible)
- Show clear message that brightness sync won't work without permission
- Provide easy way to open System Settings

---

## macOS Version Compatibility

### MonitorControl's Compatibility Table Pattern

| TwinKley Version | macOS Version |
|------------------|---------------|
| v1.3.x | Monterey 12.0+ |
| v1.2.x | Big Sur 11.0+ |
| v1.0.x | Catalina 10.15+ |

### Testing Matrix

Before release, test on:
- [ ] Oldest supported macOS (VM or old Mac)
- [ ] Current macOS release
- [ ] macOS beta (if available)
- [ ] Intel Mac (if supporting)
- [ ] Apple Silicon Mac

---

## GitHub Actions CI/CD

Automate builds and releases:

```yaml
# .github/workflows/release.yml
name: Release

on:
  push:
    tags:
      - 'v*'

jobs:
  build:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v4

      - name: Build
        run: ./build.sh

      - name: Create DMG
        run: |
          brew install create-dmg
          create-dmg \
            --volname "TwinKley" \
            --window-size 600 400 \
            --icon-size 100 \
            --icon "TwinKley.app" 150 190 \
            --app-drop-link 450 190 \
            TwinKley.dmg \
            build/Build/Products/Release/TwinKley.app

      # Note: Notarization requires secrets for Apple ID credentials
      # - name: Notarize
      #   env:
      #     APPLE_ID: ${{ secrets.APPLE_ID }}
      #     TEAM_ID: ${{ secrets.TEAM_ID }}
      #     APP_PASSWORD: ${{ secrets.APP_PASSWORD }}
      #   run: |
      #     xcrun notarytool submit TwinKley.dmg ...

      - name: Create Release
        uses: softprops/action-gh-release@v1
        with:
          files: TwinKley.dmg
          generate_release_notes: true
```

---

## Landing Page Examples

Simple landing pages from successful apps:

### rectangleapp.com Structure
- Hero with screenshot and download button
- Feature list with icons
- Keyboard shortcuts reference
- FAQ section
- GitHub link

### mac-stats.com Structure
- Large screenshot
- Download button + Homebrew command
- Links to GitHub

### Minimal Approach (GitHub Pages)

Create `docs/index.html` or use GitHub Pages with Jekyll:

```markdown
---
layout: default
---

# TwinKley

Syncs your Mac's keyboard backlight to display brightness.

[Download Latest Release](https://github.com/user/TwinKley/releases/latest)

![Screenshot](screenshot.png)

## Features
- Instant sync when you press brightness keys
- Optional timed sync
- Battery-aware
- Tiny footprint

[View on GitHub](https://github.com/user/TwinKley)
```

---

## Launch Strategy

### Soft Launch (GitHub only)
1. Create polished README
2. Tag v1.0.0 release
3. Share in relevant communities (r/macapps, Twitter)
4. Gather feedback, fix issues

### Growth Phase
1. Submit to curated lists (awesome-mac, etc.)
2. Create Homebrew cask
3. Write blog post about development
4. Submit to Hacker News "Show HN"

### Polish Phase
1. Create landing page
2. Add Sparkle auto-updates
3. Consider Product Hunt launch
4. Localization (if demand exists)

---

## App Store Considerations

### Why NOT App Store for TwinKley

TwinKley uses:
- **Private frameworks** (`DisplayServices.framework`) - Not allowed
- **CGEvent tap** - Requires entitlements Apple may reject
- **System-level brightness control** - Sandboxing issues

MonitorControl has a separate "Lite" version for App Store with reduced functionality.

### If You Want App Store Later

Would need to:
- Remove private framework usage
- Use only public APIs (limited brightness control)
- Full sandboxing compliance
- Separate codebase/target

---

## Similar Apps to Study

### Direct Competitors
- **MonitorControl** - External display brightness (32k stars)
- **Lunar** - Display brightness with more features (paid)
- **BetterDisplay** - Advanced display management (paid)

### Menu Bar App Patterns
- **Stats** - System monitor (35k stars) - Great README
- **Rectangle** - Window management (28k stars) - Clean website
- **Dozer** - Hide menu bar items - Simple utility pattern
- **Itsycal** - Menu bar calendar - Minimal but polished

### What Makes Them Successful
1. **Solves real problem** clearly
2. **Just works** - minimal configuration
3. **Polished UI** - looks native
4. **Good documentation** - clear README, FAQ
5. **Responsive maintainer** - GitHub issues answered
6. **Free/open source** - builds trust

---

## Potential Future Features

Based on MonitorControl and user requests in similar apps:

- [ ] Sync to external displays (DDC)
- [ ] Custom keyboard shortcuts
- [ ] Brightness presets/profiles
- [ ] Schedule-based brightness
- [ ] Touch Bar support (older Macs)
- [ ] Ambient light sensor integration
- [ ] Multi-display support

---

*Last updated: January 2026*
