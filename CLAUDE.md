# TwinK[l]ey - Project Guidelines

Project conventions and context for AI assistants.

---

## Core Principles (CRITICAL)

**These principles guide EVERY design decision. They are non-negotiable.**

**Priority ordering: Energy > Memory > Binary Size**

When trade-offs arise, optimize in this order:
1. Energy efficiency (CPU wake-ups, polling) - most important
2. Memory usage (resident footprint, caches)
3. Binary size (code footprint, dependencies) - least important

### 1. Energy & CPU Efficiency First
- **Event-driven architecture**: Wake only when needed (notifications, callbacks, event taps)
- **Zero polling** where events exist (brightness keys generate events, use them!)
- **Lazy loading**: Load frameworks/resources only when actually used
- **Debounce rapid events**: Coalesce multiple events to reduce CPU wake-ups
- **Battery awareness**: Degrade gracefully on battery power

**Rule**: Before adding any timer, polling loop, or background work, prove no event-driven alternative exists.

### 2. Memory & Binary Size Efficiency
- **Minimal footprint**: Target ~11 MB resident memory, ~150 KB binary
- **Small binary**: Strip symbols, avoid bloat, question every dependency
- **Lazy loading**: Load frameworks only when actually used (like Sparkle)
- **Dynamic loading**: Use `dlopen()` for truly optional components
- **No memory leaks**: Use `passUnretained` for callbacks we don't own
- **Clean up resources**: Invalidate taps, remove observers, stop timers on quit

**Rule**: Every MB of memory and every KB of binary size matters. Question every framework, every cache, every retained object, every dependency.

### 3. Privacy First
- **Zero data collection**: No analytics, telemetry, or crash reports
- **Local-only storage**: Settings in `~/.twinkley.json`, logs in `~/.twinkley-debug.log`
- **Minimal permissions**: Only Accessibility (required for brightness detection)
- **Transparent updates**: Sparkle checks disclose what's transmitted (version, OS, arch only)

**Rule**: If it touches the network or reads anything beyond brightness/power state, question it.

### 4. Simplicity
- **Single-purpose utility**: Sync keyboard brightness to display brightness. That's it.
- **No feature creep**: Every feature request must justify its existence
- **Minimal UI**: Menu bar icon, simple preferences, done
- **Small codebase**: One app file, core library for testable logic

**Rule**: The best code is no code. The best feature is no feature.

---

## Naming Convention

The app name uses artistic spelling with brackets around the 'l':

| Context | Spelling | Example |
|---------|----------|---------|
| User-facing strings | `TwinK[l]ey` | Menu items, dialogs, documentation |
| Technical identifiers | `TwinKley` | Bundle ID, module names, file paths |

**Code constants:**
- `AppInfo.name` = `"☀️ TwinK[l]ey ⌨️"` - Full name with emojis (About dialog)
- `AppInfo.shortName` = `"TwinK[l]ey"` - Short name (menu items)
- `AppInfo.identifier` = `"com.local.TwinKley"` - Bundle ID (no brackets)

**Module/package names:** `TwinKley`, `TwinKleyCore` (no brackets - technical)

---

## Design Philosophy

### 1. Event-Driven, Not Polling
The app should wake up only when something happens, not on a schedule.

**Preferred:** Notifications, callbacks, event taps
**Avoid:** Timers, polling loops, background threads

Current event sources (all instant, no polling):
- `CGEventTap` - Brightness changes (keys, Control Center, Touch Bar, etc.)
- `IOPSNotificationCreateRunLoopSource` - Power state changes
- `NSWorkspace.didWakeNotification` - Screen wake
- `com.apple.screenIsUnlocked` - Screen unlock
- `CGDisplayRegisterReconfigurationCallback` - Display changes

**Important:** Control Center brightness slider DOES generate `NX_SYSDEFINED` events (discovered January 2026). The 10-second fallback timer is only needed for silent API-level brightness changes that bypass the event system. See NOTES.md "Control Center Brightness Events Discovery" section.

### 2. Battery-Aware
Respect the user's battery. Features should gracefully degrade on battery power.

- Timer can auto-pause on battery or low battery (user setting)
- Keypress sync always works (instant, no polling)
- Default: pause polling at <20% battery

### 3. Minimal Footprint
The app should be invisible until needed.

| Target | Value |
|--------|-------|
| Binary | ~150 KB |
| Memory | ~11 MB (base), ~14 MB (when Sparkle loaded) |
| Idle CPU | 0% |
| Bundle | ~3.1 MB (includes Sparkle framework ~2.8 MB) |

**Notes:**
- Binary size includes ~17KB overhead from code signing (required for Accessibility permissions)
- Sparkle framework adds ~2.8 MB to bundle but loads lazily (only when checking for updates)
- Memory usage increases by ~3 MB only when user checks for updates or opens Preferences

### 4. No Over-Engineering
Keep it simple. This is a single-purpose utility.

- One source file for app logic (`main.swift`)
- Core module only for testable, reusable code
- No unnecessary abstractions
- No feature creep

---

## Code Quality Standards

Based on comprehensive code review (v1.3):

### Memory Management
- **CGEvent callbacks**: Use `passUnretained`, not `passRetained` (we don't own the event)
- **Framework handles**: Cache `dlopen` handles, don't reopen per call
- **Cleanup on quit**: Invalidate taps, unregister callbacks, remove observers

### Energy Efficiency
- **Timer tolerance**: Always set `.tolerance = interval * 0.1` for coalescing
- **Debounce rapid events**: Use `Debouncer` for keypress handling
- **Stop timers when disabled**: Don't let timers fire unnecessarily

### Resource Cleanup Checklist
When the app quits, clean up:
- [ ] `CFMachPortInvalidate()` for event taps
- [ ] `CGDisplayRemoveReconfigurationCallback()` for display callbacks
- [ ] `CFRunLoopRemoveSource()` for power monitor
- [ ] `NotificationCenter.removeObserver(self)`
- [ ] Invalidate all timers

---

## Technical Constraints

### M4 Mac Quirks
- Brightness keys send `keyCode=6` (NX_POWER_KEY), not codes 2/3
- `AppleLMUController` doesn't exist (pre-2015 only)
- Some IOKit services are missing or renamed

### Private Frameworks Required
No public APIs exist for keyboard brightness. We use:
- `CoreBrightness.framework` → `KeyboardBrightnessClient`
- `DisplayServices.framework` → `DisplayServicesGetBrightness`

Load dynamically with `dlopen`/`dlsym`. Cache handles.

### What Does NOT Work on M4
Documented in NOTES.md - don't re-attempt these:
- `IORegistryEntrySetCFProperties` with `KeyboardBacklightBrightness`
- `BrightnessSystemClient.setProperty:withKey:keyboardID:`
- Any `AppleLMUController` approach
- Brightness change notifications (none fire reliably)

---

## Project Structure

```
Sources/
  App/main.swift       - Main app, AppDelegate (~1100 lines)
  UI/                  - Dynamic library for windows/dialogs
    TwinKleyUI.swift   - UI loader and CLI utilities
    DebugWindow.swift  - Debug window
    PreferencesWindow.swift - Settings UI
    AboutWindow.swift  - About dialog
Packages/
  TwinKleyCore/        - Local package (dynamic library, shared)
    Sources/TwinKleyCore/
      Settings.swift   - AppInfo, Settings, SettingsManager
      Debouncer.swift  - Debounce utility for coalescing events
Tests/
  AppInfoTests.swift   - App metadata tests
  SettingsTests.swift  - Settings persistence tests (22 tests)
  DebouncerTests.swift - Debouncer unit tests (8 tests)
```

### Core vs App vs UI Split
- **Core** (TwinKleyCore): Pure Swift, no system dependencies, fully testable, shared dynamic library
- **App**: Main binary, system integration, minimal footprint
- **UI** (TwinKleyUI): Windows, dialogs, CLI utilities, loaded on-demand

This split enables **98.18% total line coverage** on the Core module (v1.8).

---

## Testing Philosophy

### Coverage Goals
- **Core module**: 98.18% line coverage (v1.8)
- **App module**: Not tested (requires hardware/permissions)
- **Total**: 53 tests across 3 test suites

High coverage achieved through:
- Protocol-based dependency injection for brightness services
- Pure Swift business logic in Core module
- Comprehensive settings and debouncer tests
- Backward compatibility testing for settings migrations

### What We Test (Core module)
- Settings serialization and persistence (18 tests, including backward compatibility)
- Interval clamping and validation
- App metadata format (3 tests)
- Debouncer timing behavior (8 tests)
- BrightnessService protocol conformance

### What We Don't Test (App module)
These require real hardware or permissions:
- Display brightness reading
- Keyboard brightness control
- CGEvent tap functionality
- Power state monitoring

### Running Tests
```bash
swift test                    # All 53 tests
swift test --filter Debouncer # Specific suite
./audit.sh                    # Full audit including tests
swift test --enable-code-coverage  # With coverage report
```

---

## Build & Development

```bash
./build.sh -d -i       # Fast dev build (~3s, Apple Development cert, skip checks)
./build.sh -i          # Normal build (~10s, all checks)
./build.sh --release   # Release build (Developer ID, notarization-ready)
swift build            # Debug build
swift test             # Run all tests (52 total)
./audit.sh             # Full quality audit
./audit.sh --quick     # Skip AI analysis
```

**Build modes:**
- **Fast (`-d`)**: Skips checks, reuses icon, uses Apple Development cert
- **Normal**: All checks (format, lint, tests), Apple Development cert
- **Release (`--release`)**: All checks, Developer ID cert, hardened runtime for notarization

### Debug Mode
```bash
~/Applications/TwinKley.app/Contents/MacOS/TwinKley --debug
```

Debug output goes to `~/.twinkley-debug.log` (file-based for background apps).

### Simulating Brightness Keys (for testing)

AppleScript CAN simulate brightness keys (contrary to some documentation):

```bash
# Brightness DOWN
osascript -e 'tell application "System Events" to key code 145'

# Brightness UP
osascript -e 'tell application "System Events" to key code 144'
```

These trigger both the display brightness change AND the CGEventTap detection. Useful for automated testing of keypress sync.

### Programmatic Brightness Control

Use the included script:
```bash
swift scripts/set_brightness.swift       # Toggle ±10%
swift scripts/set_brightness.swift 0.5   # Set to 50%
```

## Writing CHANGELOG Entries

When preparing a release or updating CHANGELOG.md, **always validate against git history** to ensure accuracy.

### Before Writing CHANGELOG

**Check what actually changed:**
```bash
# Compare since last release tag
git log v1.0.0-beta3..HEAD --oneline

# Detailed changes with file names
git log v1.0.0-beta3..HEAD --stat

# See actual diff
git diff v1.0.0-beta3..HEAD
```

### Validation Process

1. **Review commit history** - Don't rely on memory, check actual commits
2. **Categorize changes** - Added, Changed, Fixed, Removed, Deprecated
3. **Cross-reference with git diff** - Verify claimed features actually exist in code
4. **Check for breaking changes** - API changes, config format changes, etc.

### CHANGELOG Format

Follow [Keep a Changelog](https://keepachangelog.com/):

```markdown
## [X.Y.Z] - YYYY-MM-DD

### Added
- New features with brief description

### Changed
- Changes to existing functionality

### Fixed
- Bug fixes

### Note
Optional notes about the release (e.g., "Test release for auto-update")
```

### Example Workflow

```bash
# User asks to prepare release
# 1. Check what changed
git log v1.0.0-beta3..HEAD --oneline

# 2. Show user the commits and ask them to confirm what to highlight
# 3. Write CHANGELOG based on actual commits, not assumptions

# 4. Validate: does the CHANGELOG match the code changes?
git diff v1.0.0-beta3..HEAD -- path/to/changed/files
```

### Important Rules

- ❌ **Don't guess** what changed - check git history
- ❌ **Don't claim features** that aren't in the commits
- ✅ **Always validate** CHANGELOG against `git log` and `git diff`
- ✅ **Keep it user-focused** - what does this change mean for users?
- ✅ **Be accurate** - CHANGELOG is a contract with users

---

## Key Files Reference

| File | Purpose |
|------|---------|
| `NOTES.md` | **LOCAL ONLY** - Technical research, debugging notes (never commit to Git!) |
| `NEXT-STEPS-RELEASE.md` | **LOCAL ONLY** - Release planning, beta testing checklists (never commit to Git!) |
| `local_docs/` | **LOCAL ONLY** - Internal documentation (distribution notes, setup guides, etc.) |
| `local_scripts/` | **LOCAL ONLY** - Helper scripts (certificate export, secret management, etc.) |
| `CONTRIBUTING.md` | Development setup, code style, testing guide |
| `build.sh` | Builds app bundle with icon optimization |
| `audit.sh` | Pre-release quality checks |

**IMPORTANT: Local-only files and directories (`NOTES.md`, `NEXT-STEPS-RELEASE.md`, `local_docs/`, `local_scripts/`) are for development only and are gitignored. Never commit them to the repository.**

---

## Common Patterns

### Loading Private Frameworks
```swift
private var frameworkHandle: UnsafeMutableRawPointer? = {
    dlopen("/System/Library/PrivateFrameworks/Example.framework/Example", RTLD_NOW)
}()
```

### Calling ObjC Methods with Primitives
```swift
private static let objcMsgSendPtr: UnsafeMutableRawPointer = {
    dlsym(dlopen(nil, RTLD_NOW), "objc_msgSend")!
}()

typealias SetFunc = @convention(c) (AnyObject, Selector, Float, UInt64) -> Bool
let setFunc = unsafeBitCast(objcMsgSendPtr, to: SetFunc.self)
```

### Debouncing Events
```swift
private let debouncer = Debouncer(delay: 0.3)

func onEvent() {
    action()  // Immediate for responsiveness
    debouncer.debounce { [weak self] in
        self?.action()  // Final sync after events settle
    }
}
```

---

## Permissions

### CGEventTap Options and Required Permissions

- **`.listenOnly`** → Requires **Input Monitoring** permission
- **`.defaultTap`** → Requires **Accessibility** permission

This app uses **`.defaultTap`**, so users must add it to **System Settings > Privacy & Security > Accessibility**.

**Why `.defaultTap` instead of `.listenOnly`?**
On macOS Sequoia, Input Monitoring permissions don't work reliably for ad-hoc signed apps when launched via `open` or Finder. Using `.defaultTap` with Accessibility permission is more reliable.

### Why Terminal Works But `open` Doesn't (Without Permissions)

When running the binary directly from Terminal, it inherits Terminal's permissions. When launched via `open` or Finder, the app needs its own permission entry in the TCC database.

### After Rebuilding

**With ad-hoc signing (`-s -`)**: The signature changes on each build, so you must:
1. Remove TwinKley from Accessibility
2. Re-add it from ~/Applications/
3. Restart the app

Or use `./build.sh -r` to reset permissions and open System Settings.

**With Developer ID or self-signed certificate**: Signature remains stable across rebuilds. Permissions are retained automatically.

**Tip**: Use `./scripts/setup-signing.sh` to create a free self-signed certificate for development, or use your Apple Developer ID certificate (see CONTRIBUTING.md).

---

## Don't Do

1. **Don't add features without asking** - This is intentionally minimal
2. **Don't use polling where notifications exist** - Check NOTES.md first
3. **Don't skip cleanup** - Every callback/observer needs removal
4. **Don't use passRetained for events** - Memory leak
5. **Don't remove the fallback timer** - It's necessary (no brightness notifications exist)
6. **Don't use "TwinKley" in user-facing text** - Use "TwinK[l]ey"
7. **Don't commit local-only files to Git** - NOTES.md (research) and NEXT-STEPS-RELEASE.md (planning) are gitignored

### Git Hook Setup

Install the pre-commit hook to prevent accidentally committing NOTES.md:
```bash
cp hooks/pre-commit .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

This adds an extra safety layer beyond .gitignore.

---

## AI Assistant Tips

When debugging and going in circles:
1. **Do a web search** - macOS APIs change frequently; search for recent (2024-2025) solutions
2. **Ask Codex/Claude** - Use `/codex` for a second opinion on tricky issues
3. **Check NOTES.md** - Previous debugging sessions are documented there (local file only, not in Git)

### Tool Compatibility

**Shell command aliases**: The user's shell may have aliases that conflict with standard tools:
- `grep` may be aliased to `rg` (ripgrep) with different flag syntax
- When shell tools behave unexpectedly, use `command` or `\command` to bypass aliases
- Or adapt to use the aliased tool's syntax (e.g., ripgrep patterns instead of grep)
- For the current session, you can modify aliases as needed with shell built-ins
