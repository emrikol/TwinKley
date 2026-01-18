# ☀️ TwinK[l]ey ⌨️

A lightweight macOS menu bar app that synchronizes your keyboard backlight brightness with your display brightness. Designed for M4 MacBook Pro (and other Apple Silicon Macs) where dedicated keyboard brightness keys were removed.

## Features

- **Live Sync**: Instantly syncs when you change brightness (keys, Control Center slider, etc.)
- **Timed Sync**: Background check every 10 seconds as a safety net (enabled by default)
- **Battery Aware**: Option to pause background checking when on battery
- **Minimal Resource Usage**: ~12MB memory, runs silently in the menu bar
- **Persistent Settings**: Saves preferences to `~/.twinkley.json`
- **Auto-Updates**: Built-in update system (Sparkle 2) - stay current effortlessly
- **Privacy First**: Zero data collection - everything runs locally ([Privacy Policy](PRIVACY.md))
- **Auto-start**: Optional LaunchAgent for login startup

### How It Works

TwinKley watches for macOS brightness changes and automatically syncs your keyboard backlight to match.

**Live Sync (Instant)**

When you change your display brightness, macOS sends out an internal "brightness changed" notification. TwinKley listens for these notifications and immediately updates your keyboard backlight. This works with:

- ✅ Brightness keys (Fn+F1/F2 or media keys)
- ✅ Control Center brightness slider
- ✅ Touch Bar brightness controls
- ✅ Automation tools and scripts

This is instant - no waiting, no polling, no battery drain.

**Timed Sync (Safety Net)**

Some apps or tools might change brightness without triggering macOS notifications. The timed sync checks every 10 seconds as a fallback to catch these rare cases. If Live Sync is working perfectly for you, you can disable this in the menu.

**Which should you use?**
- **Try Live Sync only first** - It works for most users and uses less battery
- **Enable Timed Sync if you notice missed syncs** - Like when using third-party brightness tools

## Requirements

- macOS (tested on macOS Sequoia with M4 MacBook Pro)
- **Accessibility permissions** (required for keypress detection)

## Installation

### Build from Source

```bash
git clone https://github.com/emrikol/TwinKley.git
cd TwinKley
./build.sh
```

This creates `~/Applications/TwinKley.app` and a LaunchAgent.

### Grant Accessibility Permissions

1. Open **System Settings** > **Privacy & Security** > **Accessibility**
2. Click the **+** button and add `TwinKley.app`
3. Enable the toggle

## Usage

### Start the App

```bash
open ~/Applications/TwinKley.app
```

Or double-click the app in Finder.

### Menu Bar Options

- **About**: Shows app info (double-click icon to toggle debug mode)
- **Check for Updates**: Manually check for new versions
- **Status**: Shows if the app is active
- **Live Sync**: Toggle instant sync (responds to brightness changes immediately)
- **Timed Sync**: Toggle background check every 10 seconds
- **Sync Now**: Manually sync brightness right now
- **Preferences**: Open settings window (⌘,)
- **Help**: Open documentation
- **Quit**: Exit the app

### Auto-start on Login

Enable:
```bash
launchctl load ~/Library/LaunchAgents/com.local.TwinKley.plist
```

Disable:
```bash
launchctl unload ~/Library/LaunchAgents/com.local.TwinKley.plist
```

### Debug Mode

Debug logs are written to `~/.twinkley-debug.log` and include timestamps, brightness events, and sync operations.

**Enable at startup:**
```bash
~/Applications/TwinKley.app/Contents/MacOS/TwinKley --debug
```

**Toggle during runtime (no restart needed):**
1. Click the menu bar icon → "About TwinK[l]ey"
2. Double-click the app icon at the top
3. Debug mode will toggle on/off with a confirmation message

This is useful for diagnosing issues without restarting the app. Perfect for investigating sync problems after sleep/wake cycles or other events.

## Configuration

Settings are stored in `~/.twinkley.json`:

```json
{
  "liveSyncEnabled": true,
  "timedSyncEnabled": true,
  "timedSyncIntervalMs": 10000,
  "pauseTimedSyncOnBattery": false,
  "pauseTimedSyncOnLowBattery": true,
  "brightnessGamma": 1.5
}
```

| Setting | Description | Default |
|---------|-------------|---------|
| `liveSyncEnabled` | Instant sync when brightness changes | `true` |
| `timedSyncEnabled` | Background check every 10s as safety net | `true` |
| `timedSyncIntervalMs` | Polling interval (100-60000ms) | `10000` |
| `pauseTimedSyncOnBattery` | Pause polling when on battery | `false` |
| `pauseTimedSyncOnLowBattery` | Pause polling when battery < 20% | `true` |
| `brightnessGamma` | Gamma correction for brightness curve (0.5-4.0) | `1.5` |

### Brightness Gamma Correction

**TL;DR:** The default gamma of 1.5 dims the keyboard at low display brightness levels. Adjust if needed.

<details>
<summary><strong>Why is this needed?</strong></summary>

Human eyes perceive brightness non-linearly—we're more sensitive to changes in dark tones than bright ones. Without gamma correction, the keyboard may appear too bright or turn off before the display at low brightness levels.

The gamma correction formula applies a power curve:
```
keyboardBrightness = pow(displayBrightness, gamma)
```

**Examples with gamma = 1.5:**
| Display | Keyboard (γ=1.0 linear) | Keyboard (γ=1.5) |
|---------|-------------------------|------------------|
| 100% | 100% | 100% |
| 50% | 50% | 35% |
| 25% | 25% | 12.5% |
| 10% | 10% | 3.2% |
| 6.25% | 6.25% | 1.6% |

**Key findings:**
- Both display and keyboard brightness range from 0.0 (off) to 1.0 (full brightness)
- Physical brightness keys can reach true 0.0 and 1.0
- Gamma values suppress low brightness without creating "sticky zones" where the keyboard turns off before the display

</details>

<details>
<summary><strong>Recommended values</strong></summary>

| Value | Effect |
|-------|--------|
| `1.0` | No correction (linear) - keyboard tracks display 1:1 |
| `1.5` | Mild correction (default) - dims keyboard slightly at low levels |
| `2.0` | Moderate correction - keyboard noticeably dimmer at low levels |
| `2.2` | sRGB-like - aggressive dimming at low brightness |

**Start with `1.5` (default)** and adjust based on preference:
- If keyboard is too bright at low display brightness → increase gamma
- If keyboard turns off before display → decrease gamma
- Lower values = brighter keyboard at low display levels

</details>

<details>
<summary><strong>References</strong></summary>

- [Gamma Correction - Wikipedia](https://en.wikipedia.org/wiki/Gamma_correction) - Background on why displays use gamma curves
- [LED Brightness and Human Perception](https://hackaday.com/2016/08/23/rgb-leds-how-to-master-gamma-and-hue-for-perfect-brightness/) - Why LEDs need gamma correction for perceived linearity

*Note: Apple doesn't publish documentation about keyboard backlight brightness response curves. The 2.2 gamma recommendation is based on standard sRGB gamma and empirical testing.*

</details>

## How It Works

The app uses Apple's private frameworks:
- **CoreBrightness.framework**: `KeyboardBrightnessClient` to control keyboard backlight
- **DisplayServices.framework**: `DisplayServicesGetBrightness` to read display brightness

Brightness change detection uses `CGEventTap` to intercept macOS brightness events (`NX_SYSDEFINED` events).

<details>
<summary><strong>Technical Details: How macOS Brightness Events Work</strong></summary>

**Our Theory (Based on Testing):**

When you change display brightness, macOS posts internal "brightness changed" notifications. We believe this happens AFTER the brightness changes, not as a trigger for the change. Evidence:

| Source | Observed Behavior |
|--------|-------------------|
| **Physical keys** | Generate discrete brightness steps (e.g., 0.5000 → 0.4375 → 0.3750) |
| **Control Center slider** | Generate continuous analog values (e.g., 0.5009 → 0.4910 → 0.3830) |
| **Both** | Post the same event type: `NX_SYSDEFINED` with keyCode=6 (on M4 Macs) |

When you drag the Control Center slider from 0% to 100%, macOS fires multiple `NX_SYSDEFINED` events - one for each brightness level crossed. This is similar to holding down a physical brightness key.

**Why this matters:**
- "Live Sync" isn't just for keypresses - it catches ALL brightness events
- Control Center, Touch Bar, physical keys - all work instantly
- The only time the 10-second timer is needed is for apps that bypass the event system entirely

See `NOTES.md` for full debug logs and detailed investigation.

</details>

## Technical Notes

- M4 MacBooks use `keyCode=6` for display brightness keys (different from older Macs which use codes 2/3)
- The app requires Accessibility permissions for the event tap to function
- See `NOTES.md` for detailed research notes on the implementation

## Privacy

**TwinKley collects zero user data.** Everything runs locally on your Mac.

- ❌ No analytics or telemetry
- ❌ No crash reports
- ❌ No network connections (except update checks)
- ✅ Settings stored locally in `~/.twinkley.json`
- ✅ Optional debug logs in `~/.twinkley-debug.log`

Auto-updates use Sparkle framework and only transmit: app version, macOS version, and CPU architecture. No personally identifiable information.

**Read our full [Privacy Policy](PRIVACY.md)** for complete details.

## License

This project is licensed under the GNU General Public License v3.0 - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [KBPulse](https://github.com/EthanRDoesMC/KBPulse) - For the KeyboardBrightnessClient approach
