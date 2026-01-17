# Contributing to TwinKley

This document covers development setup, code style, testing, and contribution guidelines.

## Prerequisites

### Required
- **macOS 13+** (Ventura or later)
- **Swift 5.9+** (comes with Xcode or Command Line Tools)
- **Homebrew** (for installing development tools)

### Optional (but recommended)
- **Xcode** (full installation, not just Command Line Tools) - Required for running unit tests
- **SwiftLint** - Code linting
- **SwiftFormat** - Code formatting
- **pngquant** - Icon optimization (lossy PNG compression)

## Development Setup

### 1. Clone the Repository

```bash
git clone https://github.com/yourusername/TwinKley.git
cd TwinKley
```

### 2. Install Development Tools

```bash
# Install linter, formatter, and icon optimizer
brew install swiftlint swiftformat pngquant
```

### 3. Build the Project

This project uses **Swift Package Manager (SPM)**, the standard build system for Swift.

#### Build Script Modes

The `build.sh` script provides multiple build modes for different workflows:

```bash
# Fast iteration (skip checks, Apple Development cert)
./build.sh -d -i

# Normal build (all checks, Apple Development cert)
./build.sh -i

# Release build (Developer ID cert, hardened runtime)
./build.sh --release

# Distribution build (notarized for public release)
./build.sh --release --notarize
```

**See all options:**
```bash
./build.sh -h
```

#### Direct SPM Commands

You can also use SPM directly for basic builds:

```bash
swift build              # Build debug
swift build -c release   # Build release
swift test               # Run tests (requires Xcode)
swift package clean      # Clean build artifacts
swift package update     # Update dependencies
```

**Note**: Using `./build.sh` is recommended as it handles code signing, app bundle creation, icon generation, and installation.

## Project Structure

```
TwinKley/
├── Sources/
│   ├── App/
│   │   └── main.swift           # Main executable (UI, system integration)
│   └── Core/
│       ├── Settings.swift       # Settings model and persistence
│       └── Version.swift        # App version info
├── Tests/
│   ├── SettingsTests.swift      # Settings unit tests
│   └── AppInfoTests.swift       # Version/info tests
├── Package.swift                # Swift Package Manager manifest
├── .swiftlint.yml              # SwiftLint configuration
├── .swiftformat                # SwiftFormat configuration
├── build.sh                    # Build script
├── audit.sh                    # Distribution audit script
├── generate_icon.sh            # Icon generator
├── README.md                   # User documentation
├── CONTRIBUTING.md             # This file
├── NOTES.md                    # Technical research notes
└── LICENSE                     # GPLv3
```

## Code Style

### SwiftLint

SwiftLint enforces Swift style guidelines. Run it before committing:

```bash
# Check for issues
swiftlint

# Some issues can be auto-fixed
swiftlint --fix
```

Configuration is in `.swiftlint.yml`. Key rules:
- Max line length: 120 characters (warning), 200 (error)
- Max function body: 60 lines (warning), 100 (error)
- Sorted imports
- No force unwrapping (warning)

### SwiftFormat

SwiftFormat automatically formats code:

```bash
# Format all Swift files
swiftformat .

# Preview changes without applying
swiftformat . --dryrun
```

Configuration is in `.swiftformat`. Key settings:
- 4-space indentation
- Max line width: 120
- Sorted imports
- Trailing commas

### Style Guidelines

1. **Naming**: Use camelCase for variables/functions, PascalCase for types
2. **Comments**: Prefer self-documenting code; add comments for "why", not "what"
3. **Access control**: Use most restrictive access level possible
4. **Optionals**: Prefer `guard let` for early returns, `if let` for conditional logic

## Testing

### Requirements

**Note**: Running tests requires the full Xcode installation, not just Command Line Tools. This is because XCTest is part of the Xcode framework.

To check your setup:
```bash
xcode-select -p
# Should show: /Applications/Xcode.app/Contents/Developer
# NOT: /Library/Developer/CommandLineTools
```

If needed, switch to Xcode:
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### Running Tests

```bash
# Run all tests
swift test

# Run with verbose output
swift test --verbose

# Run specific test
swift test --filter SettingsTests
```

### Code Coverage

Run tests with coverage enabled:

```bash
swift test --enable-code-coverage
```

View the coverage report:

```bash
xcrun llvm-cov report \
  .build/debug/TwinKleyPackageTests.xctest/Contents/MacOS/TwinKleyPackageTests \
  -instr-profile=.build/debug/codecov/default.profdata \
  -ignore-filename-regex=".build|Tests"
```

For a detailed line-by-line report:

```bash
xcrun llvm-cov show \
  .build/debug/TwinKleyPackageTests.xctest/Contents/MacOS/TwinKleyPackageTests \
  -instr-profile=.build/debug/codecov/default.profdata \
  -ignore-filename-regex=".build|Tests"
```

Current coverage: **~83% line coverage** on the Core library.

### What's Tested

- **Settings.swift**: Interval clamping, serialization, defaults
- **Version.swift**: Version format validation

### What's NOT Tested

These require real hardware or permissions and can't be unit tested:

- Display brightness reading (DisplayServices framework)
- Keyboard brightness control (CoreBrightness framework)
- Event tap / key monitoring (requires Accessibility permissions)

### Manual Integration Testing

For testing keypress detection and brightness sync:

```bash
# Automated test (uses AppleScript to simulate brightness keys)
./scripts/test-keypress.sh --auto

# Interactive test (watch logs while pressing physical keys)
./scripts/test-keypress.sh
```

**AppleScript key codes for brightness:**
- `key code 145` = Brightness DOWN
- `key code 144` = Brightness UP

These can be used to verify the event tap is working without pressing physical keys.

**Gamma correction testing:**
```bash
# Test brightness sync across full range with gamma correction
./scripts/test-gamma.sh
```

This script:
1. Starts the app in debug mode
2. Captures initial brightness
3. Simulates pressing down to minimum, up to maximum
4. Returns to initial brightness
5. Shows summary with min/max values

**Important AppleScript Quirk:**
- Physical brightness keys can reach **true 0.0 and 1.0** (full range)
- AppleScript key simulation **stops at 0.0625 (min) and 0.9375 (max)** - 16-step quantization boundaries
- This is a limitation of simulated events, not actual hardware/API capabilities
- For testing full 0.0-1.0 range, use **manual physical keypresses** instead of AppleScript
- The test script is useful for automated testing, but manual verification is more reliable

**Brightness adjustment utilities:**
```bash
# Set display brightness programmatically
swift scripts/set_brightness.swift 0.5   # Set to 50%
swift scripts/set_brightness.swift       # Toggle ±10%
```

### Writing Tests

Place tests in `Tests/` directory. Each test file should:
- Import `XCTest` and `@testable import TwinKleyCore`
- Extend `XCTestCase`
- Use descriptive test method names: `testFeatureBehavior()`

Example:
```swift
import XCTest
@testable import TwinKleyCore

final class MyFeatureTests: XCTestCase {
    func testSomethingWorks() {
        let result = myFunction()
        XCTAssertEqual(result, expected)
    }
}
```

## Making Changes

### Workflow

1. Create a feature branch: `git checkout -b feature/my-feature`
2. Make changes
3. Run linter: `swiftlint`
4. Run formatter: `swiftformat .`
5. Run tests (if Xcode available): `swift test`
6. Build and test manually: `./build.sh && open ~/Applications/TwinKley.app`
7. Run audit before committing: `./audit.sh --quick`
8. Commit with descriptive message
9. Open pull request

### Commit Messages

Use conventional commit format:
```
type: short description

Longer explanation if needed.
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting, no code change
- `refactor`: Code change that doesn't fix bug or add feature
- `test`: Adding tests
- `chore`: Maintenance tasks

### Debug Mode

When testing changes, use debug mode to see detailed output:

```bash
# Run with debug output
~/Applications/TwinKley.app/Contents/MacOS/TwinKley --debug
```

## Architecture Notes

### Why Private Frameworks?

Apple doesn't provide public APIs for keyboard brightness control. We use:
- **CoreBrightness.framework**: `KeyboardBrightnessClient` for keyboard backlight
- **DisplayServices.framework**: `DisplayServicesGetBrightness` for screen brightness

These are loaded dynamically at runtime using `dlopen`/`dlsym`.

### Core vs App Split

- **Core** (`Sources/Core/`): Testable business logic, no UI or system dependencies
- **App** (`Sources/App/`): Main executable with UI, system framework integration

This split allows unit testing the settings logic without requiring hardware.

## Code Signing

### The Problem

TwinKley requires Accessibility permissions for keypress detection. macOS identifies apps by their code signature. With ad-hoc signing (the default), the signature changes every rebuild, so macOS treats it as a "new" app and you must re-grant permissions.

### Solutions

| Approach | Cost | Stability | Distribution |
|----------|------|-----------|--------------|
| Ad-hoc signing | Free | Unstable (re-add permissions each build) | Local only |
| Self-signed certificate | Free | Stable | Local only (Gatekeeper blocks) |
| Apple Developer ID | $99/year | Stable | Distributable |

### Option 1: Self-Signed Certificate (Recommended for Development)

Run the setup script:

```bash
./scripts/setup-signing.sh
```

This creates a certificate called "TwinKley Development" in your login keychain.

Then build with it:

```bash
./build.sh -s "TwinKley Development"
```

**Manual creation** (if the script doesn't work):

1. Open **Keychain Access** (in /Applications/Utilities/)
2. Menu: **Keychain Access → Certificate Assistant → Create a Certificate...**
3. Configure:
   - **Name:** `TwinKley Development`
   - **Identity Type:** `Self Signed Root`
   - **Certificate Type:** `Code Signing`
4. Click **Create**
5. Build: `./build.sh -s "TwinKley Development"`

### Option 2: Apple Developer ID

If you have an Apple Developer Program membership ($99/year):

1. Open Xcode → Settings → Accounts
2. Select your team → Manage Certificates
3. Create a "Developer ID Application" certificate
4. Build: `./build.sh -s "Developer ID Application: Your Name (TEAMID)"`

**Default behavior**: The build script now defaults to using the Developer ID certificate if available.

### Notarization for Distribution

If you want to distribute TwinKley to others (GitHub releases, direct download), you should notarize the app to prevent "unidentified developer" warnings.

**Requirements:**
- Apple Developer Program membership ($99/year)
- Developer ID Application certificate (see Option 2 above)
- App-specific password from appleid.apple.com (for notarytool credentials)

**One-time setup:**

```bash
# Store notarization credentials in keychain
xcrun notarytool store-credentials "notarytool" \
  --apple-id "your-apple-id@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"  # App-specific password
```

Get app-specific password at: https://appleid.apple.com/account/manage

**Build and notarize (automated):**

```bash
# Build, sign, notarize, and staple in one command
./build.sh --release --notarize
```

This automatically:
1. Builds with Developer ID certificate
2. Enables hardened runtime
3. Submits to Apple notarization service
4. Waits for approval (1-5 minutes)
5. Staples the ticket to the app

**Verify notarization:**

```bash
spctl -a -vv ~/Applications/TwinKley.app
# Should show: accepted
#              source=Notarized Developer ID
```

**For detailed documentation**, see `DISTRIBUTION-WORKFLOW.md` which covers:
- Build modes (dev, release, notarization)
- Prerequisites and setup
- Distribution checklist
- Troubleshooting

**Note**: The build script automatically enables hardened runtime when using a Developer ID certificate. The required entitlements (`TwinKley.entitlements`) allow loading private frameworks with `dlopen`.

### Verifying Your Certificate

List available code signing identities:

```bash
security find-identity -v -p codesigning
```

### First-Time Setup After Signing

Even with stable signing, you need to grant Accessibility permission once:

1. Build: `./build.sh -s "TwinKley Development" -i`
2. Open **System Settings → Privacy & Security → Accessibility**
3. Add `~/Applications/TwinKley.app`
4. Enable the toggle

After this, rebuilds will retain the permission.

## Troubleshooting

### Build Errors

```bash
# Clean build cache
rm -rf .build
swift build
```

### SwiftLint Not Found

```bash
brew install swiftlint
# or
brew reinstall swiftlint
```

### pngquant Not Found

The build script will fall back to ImageOptim or skip icon optimization:
```bash
brew install pngquant
```

### Tests Won't Run

Ensure full Xcode is installed and selected:
```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
```

### App Won't Sync

1. Check Accessibility permissions in System Settings
2. Run with `--debug` flag to see event detection
3. Verify CoreBrightness framework loads (check Console.app)

## Questions?

Open an issue on GitHub for:
- Bug reports
- Feature requests
- Questions about contributing
