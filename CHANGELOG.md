# Changelog

All notable changes to TwinKley will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.0-beta9] - 2026-01-31

### Fixed
- Control Center brightness slider now triggers keyboard sync (was broken in beta8)

### Changed
- Event handling now processes both subtype 7 (Control Center) and subtype 8 (physical keys)

### Added
- `scripts/test-suppression-notifications.swift` - Research tool for CoreBrightness notification discovery

## [1.0.0-beta8] - 2026-01-31

### Fixed
- Brightness key detection now works reliably across all apps (was incorrectly reading event data)
- Simplified default `brightnessKeyCodes` to `[2, 3]` (the correct NX_KEYTYPE values)
- Control Center brightness slider now triggers sync (handles subtype 7 events)

### Changed
- NX_SYSDEFINED event handling now converts CGEvent to NSEvent before reading data1 (fixes incorrect keyCode parsing)
- Event handling now processes both subtype 7 (Control Center) and subtype 8 (physical keys)

### Added
- `docs/macos-media-keys-reference.md` - Technical reference for macOS media key handling
- `scripts/test-keytypes.swift` - Diagnostic tool for debugging brightness key detection

### Acknowledgments
- Thanks to [Chromium's media_keys_listener_mac.mm](https://chromium.googlesource.com/chromium/src/+/66.0.3359.158/ui/base/accelerators/media_keys_listener_mac.mm) for demonstrating the correct approach to reading NX_SYSDEFINED event data

## [1.0.0-beta7] - 2026-01-30

### Added
- Dynamic menu status: now shows "Locked" when ambient light sensor takes control of keyboard brightness
- Menu status updates in real-time when opening the menu (Active/Disabled/Locked/Error)

### Changed
- Build script now prefers Developer ID signing for dev builds (fixes Accessibility permission persistence)
- Removed unused `isBacklightSuppressedOnKeyboard:` selector (cleanup)

### Fixed
- Accessibility permissions now persist across rebuilds when using Developer ID certificate

## [1.0.0-beta6] - 2026-01-30

### Added
- Configurable `brightnessKeyCodes` setting for custom brightness event detection
- Troubleshooting documentation for TCC permission issues

### Fixed
- Documented fix for stale Accessibility permissions after code signature changes

### Changed
- Brightness key detection now reads from settings instead of hardcoded values

## [1.0.0-beta5] - 2026-01-28

### Fixed
- Update checking window now auto-dismisses when Sparkle dialog appears (no more lingering loading screen)

### Changed
- Build and audit scripts now use `/Applications` instead of `~/Applications` (proper system location)
- Removed all `#if !APP_STORE` conditionals (cleaner codebase, App Store impossible with private frameworks)
- Updated documentation with accurate memory measurements (12MB baseline)

## [1.0.0-beta4] - 2026-01-28

### Note
Test release to verify auto-update from beta3 → beta4.

## [1.0.0-beta3] - 2026-01-28

### Added
- DMG installer for easy drag-to-Applications installation
- Auto-incrementing build numbers (local and CI)

### Fixed
- Appcast URL now points to GitHub Pages (was broken in beta1/beta2)

### Changed
- Build version system: separate display version from Sparkle build number
- Local builds auto-increment, GitHub Actions handles canonical release versions

### Note
First release with working auto-update system and proper DMG installer.

## [1.0.0-beta2] - 2026-01-27

### Added
- Screenshots in README showing all UI elements
- Comprehensive release guide in local_docs/RELEASE-GUIDE.md

### Changed
- README now includes visual documentation of features

### Note
This is a test release to verify auto-update functionality works correctly.

## [1.0.0-beta1] - 2026-01-27

### Added
- Auto-update system using Sparkle 2
- Privacy policy (zero data collection)
- First-run welcome dialog
- Full-featured Preferences window with three tabs:
  - Sync settings (Live/Timed sync controls)
  - Advanced (Gamma correction slider)
  - Updates & Privacy (Auto-update preferences)
- Help menu with documentation links
- Runtime debug toggle via About dialog icon double-click
- GitHub Actions release automation
- Issue templates for bugs and feature requests

### Fixed
- Event tap disabled bug after sleep/wake cycles
- Added keyCode 7 for brightness detection after wake/power state changes

### Changed
- Modernized build system with notarization support
- Version management now single-source from Settings.swift

## [Previous Development Versions]

Prior to v1.0.0-beta1, TwinKley was in active development without formal releases.

Key features implemented:
- Live brightness sync via event tap
- Timed sync as fallback
- Battery-aware power management
- Gamma correction support
- Menu bar interface
- Settings persistence
