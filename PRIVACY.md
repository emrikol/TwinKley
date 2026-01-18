# Privacy Policy

**Last Updated**: January 2026

## Summary

TwinKley collects **zero user data**. Everything runs locally on your Mac.

## What We Don't Collect

- ❌ No analytics or telemetry
- ❌ No crash reports
- ❌ No usage statistics
- ❌ No personal information
- ❌ No network connections (except for update checks)

## What Runs Locally

- ✅ Brightness sync algorithms
- ✅ Settings storage (`~/.twinkley.json`)
- ✅ Debug logs (optional, local only: `~/.twinkley-debug.log`)

## Permissions Required

### Accessibility Permission

TwinKley requires **Accessibility** permission to detect brightness key presses.

**What we do:**
- Monitor system brightness events only
- Detect when you press brightness keys (Fn+F1/F2)
- Respond to Control Center brightness slider changes

**What we DON'T do:**
- Never log keystrokes or other input
- Never monitor non-brightness events
- Never send data anywhere

This permission is used solely to provide the core functionality of syncing your keyboard backlight to your display brightness.

## Auto-Updates

TwinKley uses the [Sparkle framework](https://sparkle-project.org/) to check for updates.

**What is transmitted:**
- App version number
- macOS version
- CPU architecture (arm64 or x86_64)

**What is NOT transmitted:**
- No personally identifiable information
- No usage data
- No system information beyond version numbers

Updates are checked via GitHub Releases. You control when to install updates.

## Data Storage

All data is stored locally on your Mac:

- **Settings**: `~/.twinkley.json` (JSON file, human-readable)
- **Debug logs**: `~/.twinkley-debug.log` (optional, only when debug mode enabled)
- **First-launch flag**: macOS UserDefaults (local preference file)

No data ever leaves your computer except for update checks.

## Open Source

TwinKley is fully open source under the GPL-3.0 license. You can review the entire codebase to verify our privacy claims:

[https://github.com/emrikol/TwinKley](https://github.com/emrikol/TwinKley)

## Questions?

If you have privacy concerns or questions, please open an issue on [GitHub](https://github.com/emrikol/TwinKley/issues).

## Changes to This Policy

We will update this policy if our data practices change. The "Last Updated" date at the top will reflect any changes.

Given that we collect zero data, it's unlikely this policy will change significantly.
