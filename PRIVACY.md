# Privacy Policy

**Last Updated**: February 2026

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

**What we DON'T do in normal operation:**
- Don't log keystrokes or other input
- Don't monitor non-brightness events
- Don't send data anywhere

This permission is used solely to provide the core functionality of syncing your keyboard backlight to your display brightness.

## Optional Debug Mode

TwinKley includes optional diagnostic features that are **disabled by default** and store data **locally only**. No debug data is ever transmitted over the network.

### Debug Logging

When enabled via `--debug` flag or by double-clicking the icon in the About dialog, TwinKley writes diagnostic information to `~/.twinkley-debug.log`:

- Timestamps of brightness sync operations
- Display and keyboard brightness values
- Power state changes (battery/AC status, battery level)
- Event tap status (start, stop, re-enable)
- Framework initialization status

Debug logs do **not** contain keystrokes, passwords, or personal input. Log files older than 7 days or larger than 1 MB are automatically cleaned up.

### Event Capture (Advanced Diagnostics)

The Debug Window includes a "Capture Events" feature for diagnosing brightness detection problems. **When capture is active, ALL keypresses are temporarily logged** along with key codes and brightness values. This data is:

- Displayed only in the Debug Window (not written to the debug log file)
- Captured for a user-selected duration (5-60 seconds), then capture automatically stops
- Held in memory until the user clicks "Clear", or until the app is quit
- Optionally included in a diagnostics report if the user saves one

**A prominent privacy warning is displayed** before and during capture. Do not type passwords or sensitive information while capture is active.

This feature exists because different Mac models may use different key codes for brightness events, and capture helps users identify the correct codes for their hardware.

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

- **Settings**: `~/.twinkley.json` (JSON file, human-readable, includes first-launch flag)
- **Debug logs**: `~/.twinkley-debug.log` (optional, only when debug mode enabled)

No data ever leaves your computer except for update checks.

## Open Source

TwinKley is fully open source under the GPL-3.0 license. You can review the entire codebase to verify our privacy claims:

[https://github.com/emrikol/TwinKley](https://github.com/emrikol/TwinKley)

## Questions?

If you have privacy concerns or questions, please open an issue on [GitHub](https://github.com/emrikol/TwinKley/issues).

## Changes to This Policy

We will update this policy if our data practices change. The "Last Updated" date at the top will reflect any changes.

Given that we collect zero data, it's unlikely this policy will change significantly.
