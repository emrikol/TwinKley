# Distribution Workflow Guide

## Modern macOS Distribution (2025-2026)

TwinK[l]ey now includes all modern macOS distribution requirements:
- ✅ Hardened runtime
- ✅ Universal binary support (arm64 + x86_64)
- ✅ Notarization with `xcrun notarytool`
- ✅ Stapling for offline verification

---

## Build Modes

### Development (Fast Iteration)
```bash
./build.sh -d -i
```
- **Speed**: ~3s
- **Signing**: Apple Development (or ad-hoc)
- **Architecture**: Native only
- **Purpose**: Local testing

### Normal Build
```bash
./build.sh -i
```
- **Speed**: ~10s
- **Checks**: Format, lint, tests
- **Signing**: Apple Development (with hardened runtime)
- **Architecture**: Native only
- **Purpose**: Daily development

### Release Build
```bash
./build.sh --release
```
- **Speed**: ~15s
- **Checks**: Format, lint, tests
- **Signing**: Developer ID Application
- **Architecture**: Native only
- **Hardened Runtime**: ✓ Enabled
- **Purpose**: Pre-distribution testing

### Full Distribution Build
```bash
./build.sh --release --universal --notarize
```
- **Speed**: ~60s (notarization takes 1-5 minutes)
- **Checks**: Format, lint, tests
- **Signing**: Developer ID Application
- **Architecture**: Universal (arm64 + x86_64)
- **Hardened Runtime**: ✓ Enabled
- **Notarization**: ✓ Submitted to Apple
- **Stapling**: ✓ Ticket attached
- **Purpose**: Public distribution

---

## Prerequisites

### For Development Builds

**Apple Development Certificate** (Recommended):
```bash
# Create in Xcode
Xcode → Settings → Accounts → Manage Certificates → + → Apple Development
```

Benefits:
- Permissions persist across rebuilds
- No permission reset needed

**Alternative**: Self-signed certificate
```bash
./scripts/setup-signing.sh
```

### For Distribution Builds

**1. Apple Developer Program** ($99/year)
- Required for Developer ID certificate
- Required for notarization

**2. Developer ID Application Certificate**:
```bash
# Create at developer.apple.com or in Xcode
Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application
```

**3. Notarization Credentials**:
```bash
# Create app-specific password at: https://appleid.apple.com/account/manage
# Then store credentials:
xcrun notarytool store-credentials "notarytool" \
  --apple-id "your-apple-id@example.com" \
  --team-id "YOUR_TEAM_ID" \
  --password "xxxx-xxxx-xxxx-xxxx"
```

---

## Build Flags Reference

| Flag | Description | Requires |
|------|-------------|----------|
| `-i` | Install and run after build | - |
| `-r` | Reset accessibility permissions | - |
| `-d, --dev` | Skip checks for fast iteration | - |
| `--release` | Use Developer ID certificate + hardened runtime | Developer ID cert |
| `--universal` | Build for arm64 + x86_64 | - |
| `--notarize` | Submit to Apple notarization service | `--release` |
| `-s IDENTITY` | Override signing certificate | - |

---

## Distribution Checklist

Before releasing to the public:

- [ ] **Run full distribution build**:
  ```bash
  ./build.sh --release --universal --notarize
  ```

- [ ] **Verify notarization**:
  ```bash
  spctl -a -vv ~/Applications/TwinKley.app
  # Should show: accepted
  #              source=Notarized Developer ID
  ```

- [ ] **Test on both architectures**:
  - Intel Mac (x86_64) or Rosetta 2
  - Apple Silicon (arm64)

- [ ] **Create distribution package**:
  ```bash
  # ZIP for direct download
  ditto -c -k --keepParent ~/Applications/TwinKley.app TwinKley.zip

  # Or DMG for prettier distribution
  hdiutil create -srcdir ~/Applications/TwinKley.app \
    -volname "TwinKley" \
    -format UDZO \
    TwinKley.dmg
  ```

- [ ] **Test Gatekeeper on fresh Mac**:
  - Download the ZIP/DMG
  - Extract and run
  - Should open without "unidentified developer" warning

---

## Troubleshooting

### Notarization Failed

**Get detailed logs**:
```bash
# Find your submission ID in the error output, then:
xcrun notarytool log SUBMISSION_ID --keychain-profile "notarytool"
```

**Common issues**:
- Missing hardened runtime → Use `--release` mode
- Invalid entitlements → Check `TwinKley.entitlements`
- Unsigned binaries → Ensure all binaries are signed
- Invalid timestamp → Check internet connection during signing

### Universal Build Fails

**"No such file or directory"**:
- Make sure you have Xcode Command Line Tools installed:
  ```bash
  xcode-select --install
  ```

**"cannot find -macosx SDK"**:
- Swift Package Manager may need help finding the SDK:
  ```bash
  export SDKROOT=$(xcrun --show-sdk-path)
  ./build.sh --universal
  ```

### Permissions Reset After Build

You're using ad-hoc signing (`-`). Solutions:
1. Create an Apple Development certificate (recommended)
2. Use a self-signed certificate: `./scripts/setup-signing.sh`
3. Use `-s "Certificate Name"` to specify a certificate

---

## Size Targets

| Metric | Target | Notes |
|--------|--------|-------|
| Binary (single arch) | ~150 KB | Includes ~17KB signing overhead |
| Binary (universal) | ~270 KB | arm64 + x86_64 combined |
| Bundle (total) | ~250-400 KB | Depending on architecture |
| Memory (runtime) | ~11 MB | Physical footprint |

**Universal binary overhead**: Approximately 2x the size of single-arch binary due to including both architectures.

---

## Related Documentation

- `build.sh` - Main build script
- `NOTARIZATION-SETUP.md` - Detailed notarization setup guide
- `CONTRIBUTING.md` - Development workflow
- `DISTRIBUTION-NOTES.md` - App Store and GitHub release notes
