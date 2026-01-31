# macOS Media Keys and NX_SYSDEFINED Events Reference

Technical reference for macOS media key handling, CGEventTap, and NX_SYSDEFINED events.

**Last updated:** January 31, 2026

---

## NX_KEYTYPE Constants

Official Apple key type definitions from IOKit headers.

| Constant | Value | Description |
|----------|-------|-------------|
| NX_KEYTYPE_SOUND_UP | 0 | Volume up |
| NX_KEYTYPE_SOUND_DOWN | 1 | Volume down |
| NX_KEYTYPE_BRIGHTNESS_UP | 2 | Display brightness up |
| NX_KEYTYPE_BRIGHTNESS_DOWN | 3 | Display brightness down |
| NX_KEYTYPE_CAPS_LOCK | 4 | Caps lock |
| NX_KEYTYPE_HELP | 5 | Help key |
| NX_KEYTYPE_POWER_KEY | 6 | Power key |
| NX_KEYTYPE_MUTE | 7 | Audio mute |
| NX_KEYTYPE_NUM_LOCK | 10 | Num lock |
| NX_KEYTYPE_CONTRAST_UP | 11 | Contrast up |
| NX_KEYTYPE_CONTRAST_DOWN | 12 | Contrast down |
| NX_KEYTYPE_LAUNCH_PANEL | 13 | Launch panel |
| NX_KEYTYPE_EJECT | 14 | Eject |
| NX_KEYTYPE_VIDMIRROR | 15 | Video mirror toggle |
| NX_KEYTYPE_PLAY | 16 | Play/pause |
| NX_KEYTYPE_NEXT | 17 | Next track |
| NX_KEYTYPE_PREVIOUS | 18 | Previous track |
| NX_KEYTYPE_FAST | 19 | Fast forward |
| NX_KEYTYPE_REWIND | 20 | Rewind |
| NX_KEYTYPE_ILLUMINATION_UP | 21 | Keyboard brightness up |
| NX_KEYTYPE_ILLUMINATION_DOWN | 22 | Keyboard brightness down |
| NX_KEYTYPE_ILLUMINATION_TOGGLE | 23 | Keyboard brightness toggle |

**Source:** [Apple Open Source - ev_keymap.h](https://opensource.apple.com/source/IOHIDFamily/IOHIDFamily-258.3/IOHIDSystem/IOKit/hidsystem/ev_keymap.h)

---

## NX_SYSDEFINED Event Subtypes

NX_SYSDEFINED events have different subtypes to distinguish event categories.

| Constant | Value | Description |
|----------|-------|-------------|
| NX_SUBTYPE_POWER_KEY | 1 | Power key events |
| NX_SUBTYPE_AUX_MOUSE_BUTTONS | 7 | Auxiliary mouse buttons |
| NX_SUBTYPE_AUX_CONTROL_BUTTONS | 8 | Media keys / auxiliary control buttons |
| NX_SUBTYPE_EJECT_KEY | 10 | Eject key |
| NX_SUBTYPE_SLEEP_EVENT | 11 | Sleep events |

**Important:** Media key events use subtype 8 (`NX_SUBTYPE_AUX_CONTROL_BUTTONS`). Other NX_SYSDEFINED events have different subtypes.

**Source:** [Chromium media_keys_listener_mac.mm](https://chromium.googlesource.com/chromium/src/+/66.0.3359.158/ui/base/accelerators/media_keys_listener_mac.mm)

---

## data1 Field Structure

For NX_SYSDEFINED events with subtype 8, the `data1` field is structured as:

```
data1 layout (32-bit):
┌────────────────┬────────────────┬────────────────┬────────────────┐
│   bits 24-31   │   bits 16-23   │   bits 8-15    │   bits 0-7     │
│   (unused?)    │   keyCode      │   keyState     │   flags        │
└────────────────┴────────────────┴────────────────┴────────────────┘
```

> **⚠️ WARNING:** You must read data1 from NSEvent, NOT from CGEvent directly.
> Using `CGEvent.getIntegerValueField(CGEventField(rawValue: 85)!)` gives **incorrect results**.
> See "Critical: CGEvent vs NSEvent for Reading data1" section below.

**Extracting fields (Swift) - from NSEvent.data1:**
```swift
let keyCode = Int((data1 >> 16) & 0xFF)   // bits 16-23
let keyState = Int((data1 >> 8) & 0xFF)   // bits 8-15
let keyRepeat = (data1 & 0x1)             // bit 0 (repeat flag)
```

**Alternative extraction (Objective-C):**
```objc
int keyCode = ([event data1] & 0xFFFF0000) >> 16;
int keyFlags = [event data1] & 0x0000FFFF;
BOOL keyIsPressed = (((keyFlags & 0xFF00) >> 8)) == 0xA;
```

**Source:** [Rogue Amoeba - Apple Keyboard Media Key Event Handling](https://weblog.rogueamoeba.com/2007/09/29/apple-keyboard-media-key-event-handling/)

---

## keyState Values

The keyState byte indicates key press state.

| Value | Meaning |
|-------|---------|
| 0x0A (10) | Key down |
| 0x0B (11) | Key up |
| 0x0C (12) | Key repeat (auto-repeat while held) |

**Note:** The full keyState byte may include additional flags in the lower nibble. For example:
- `0xAD` = key down (0xA) with flags (0xD)
- `0xC0` = key repeat (0xC) with no flags (0x0)

**Sources:**
- [Rogue Amoeba - Apple Keyboard Media Key Event Handling](https://weblog.rogueamoeba.com/2007/09/29/apple-keyboard-media-key-event-handling/)
- [SGnTN - Universal MediaKeys](https://www.somegeekintn.com/blog/2006/03/universal-mediakeys/)

---

## Posting Media Key Events

To programmatically post media key events:

```c
// Create event data
NXEventData event;
bzero(&event, sizeof(NXEventData));
event.compound.subType = NX_SUBTYPE_AUX_CONTROL_BUTTONS;

// On Intel (little-endian), write as long value
event.compound.misc.L[0] = (auxKeyCode << 16) | (NX_KEYDOWN << 8);

// Post the event
IOHIDPostEvent(hid_handle, NX_SYSDEFINED, location, &event, kNXEventDataVersion, 0, FALSE);
```

**Source:** [SGnTN - Universal MediaKeys](https://www.somegeekintn.com/blog/2006/03/universal-mediakeys/)

---

## CGEventTap for Media Keys

**Creating an event tap:**
```swift
let eventMask = (1 << 14)  // NX_SYSDEFINED = 14
let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,  // Requires Accessibility permission
    eventsOfInterest: CGEventMask(eventMask),
    callback: tapCallback,
    userInfo: nil
)
```

**Permission requirements:**
- `.defaultTap` requires **Accessibility** permission
- `.listenOnly` requires **Input Monitoring** permission (macOS 10.15+)

**Limitations:**
- Cannot receive Secure Keyboard Entry events (e.g., password fields)
- Must handle `kCGEventTapDisabledByTimeout` in callback
- Some apps may behave strangely when other apps observe events (e.g., Adobe apps)

**Source:** [Takayama Fumihiko - All about macOS event observation (Google Slides)](https://docs.google.com/presentation/d/1nEaiPUduh1vjks0rDVRTcJaEULbSWWh1tVdG2HF_XSU/htmlpresent)

---

## Accessing Subtype from CGEvent

CGEvent doesn't directly expose the subtype for NX_SYSDEFINED events. Workaround:

```swift
// Convert CGEvent to NSEvent to access subtype
if let nsEvent = NSEvent(cgEvent: cgEvent) {
    let subtype = nsEvent.subtype.rawValue
    if subtype == 8 {  // NX_SUBTYPE_AUX_CONTROL_BUTTONS
        // Process as media key event
    }
}
```

**Source:** [Tencent Cloud Developer Community (Chinese)](https://cloud.tencent.com/developer/ask/sof/110434768)

---

## SPMediaKeyTap (Spotify's Media Key Library)

Spotify released SPMediaKeyTap for handling media key events.

**Intercepted keyCodes:**
- NX_KEYTYPE_PLAY (16)
- NX_KEYTYPE_NEXT (17)
- NX_KEYTYPE_PREVIOUS (18)
- NX_KEYTYPE_FAST (19)
- NX_KEYTYPE_REWIND (20)

**NOT intercepted:** Brightness keys (2, 3), volume keys (0, 1, 7), keyboard illumination (21, 22, 23)

**Behavior:** "Intercepts all events in the NX_SYSDEFINED category, figures out if [the app] should intercept it, and if so, does not send it on to other apps."

**App switching:** Tracks which media key-aware app was most recently active and only intercepts events when that app is frontmost.

**Source:** [GitHub - nevyn/SPMediaKeyTap](https://github.com/nevyn/SPMediaKeyTap)

---

## Media Key Priority Problem

Common macOS issue where multiple apps compete for media key events.

**Problem:** "Sometimes, the Play button doesn't pause your Spotify client. Sometimes, the Play button plays iTunes/Music instead. Sometimes, the Play button literally just does nothing."

**Cause:** Media player prioritization in macOS. When multiple apps accept playback commands, prioritization gets shuffled.

**Apps that commonly intercept media keys:**
- Spotify
- Apple Music / iTunes
- YouTube (in browser)
- QuickTime
- Chrome tabs playing media
- Discord

**Third-party solutions:**
- [Mac Media Key Forwarder](https://github.com/milgra/macmediakeyforwarder)
- [BeardedSpice](http://beardedspice.github.io)

**Source:** [Medium - The Death of an Essential Mac App](https://alumineous.medium.com/the-death-of-a-essential-mac-app-18a167df1f71)

---

## HID Key Remapping (hidutil)

macOS 10.12+ includes `hidutil` for keyboard remapping at the driver level.

**Function key mapping:**
- Each function key maps to two HID key codes (standard function vs media key)
- Controlled by fn key state
- Customizable via `UserKeyMapping` applied in `IOHIDKeyboardFilter.mm`

**Finding key codes:**
```bash
ioreg -l | grep FnFunctionUsageMap
```

**Display brightness HID codes (Consumer Page 0x0C):**
- Display Brightness Increment: 0x6F
- Display Brightness Decrement: 0x70

**Keyboard brightness HID codes (Apple Vendor Page 0xFF01):**
- Keyboard Brightness Up: 0xFF00000009
- Keyboard Brightness Down: 0xFF00000008

**Source:** [nanoANT - macOS function key remapping with hidutil](https://www.nanoant.com/mac/macos-function-key-remapping-with-hidutil)

---

## Chromium Media Key Implementation

Chromium's media key listener demonstrates the **correct approach** - converting to NSEvent before reading data1:

```cpp
// Convert CGEvent to NSEvent
NSEvent* ns_event = [NSEvent eventWithCGEvent:event];

// Check type and subtype
if (type != NX_SYSDEFINED ||
    [ns_event subtype] != kSystemDefinedEventMediaKeysSubtype)  // subtype 8
    return event;

// Extract keyCode
NSInteger data1 = [ns_event data1];
int key_code = (data1 & 0xFFFF0000) >> 16;

// Only process specific media keys
if (key_code != NX_KEYTYPE_PLAY &&
    key_code != NX_KEYTYPE_FAST &&
    key_code != NX_KEYTYPE_REWIND &&
    key_code != NX_KEYTYPE_PREVIOUS &&
    key_code != NX_KEYTYPE_NEXT)
    return event;

// Check for key down only (ignore key up and repeat)
int key_flags = data1 & 0x0000FFFF;
bool is_key_pressed = ((key_flags & 0xFF00) >> 8) == 0xA;
if (!is_key_pressed)
    return event;
```

**Source:** [Chromium Source - media_keys_listener_mac.mm](https://chromium.googlesource.com/chromium/src/+/66.0.3359.158/ui/base/accelerators/media_keys_listener_mac.mm)

**Note:** This is the correct pattern. The key insight is that Chromium converts to NSEvent (`[NSEvent eventWithCGEvent:event]`) before reading data1 (`[ns_event data1]`). Attempting to read data1 directly from CGEvent gives incorrect results.

---

## Secure Keyboard Entry

macOS security feature that blocks CGEventTap from receiving certain events.

**When active:**
- Password fields in browsers
- Secure input fields
- Apps like 1Password when unlocked

**Behavior:** Events are simply not delivered to the tap (not modified, but blocked entirely).

**Source:** [Mozilla Bugzilla - CGEvent taps can steal HTML form passwords](https://bugzilla.mozilla.org/show_bug.cgi?id=394107)

---

## AppleScript Key Simulation vs Physical Keys

**Important discovery (January 2026):** AppleScript key simulation and physical key presses use different event pathways.

### AppleScript Key Codes for Brightness

```applescript
tell application "System Events" to key code 145  -- Brightness DOWN
tell application "System Events" to key code 144  -- Brightness UP
```

### Event Pathway Differences

| Method | Event Type | Detection |
|--------|-----------|-----------|
| Physical brightness keys | NX_SYSDEFINED (type 14) | keyCode in data1 field |
| AppleScript simulation | Regular keyDown/keyUp | keyCode 144/145 directly |

**Key finding:** AppleScript simulation generates regular `CGEventType.keyDown` events with keyCodes 144/145, NOT `NX_SYSDEFINED` events. This means:

1. Apps can detect AppleScript-simulated brightness keys via regular key event monitoring
2. Physical brightness keys require listening for NX_SYSDEFINED events
3. Testing brightness key handling with AppleScript may not accurately reflect physical key behavior

### Implications for Event Tap Development

If your app needs to detect brightness keys:
- Listen for BOTH regular keyDown (codes 122, 120, 144, 145) AND NX_SYSDEFINED events
- **Use NSEvent conversion** to read data1 correctly (see "CGEvent vs NSEvent" section below)
- NX_KEYTYPE values are consistent (2=up, 3=down) when read correctly via NSEvent
- Some apps (media players) may intercept NX_SYSDEFINED events before your tap sees them

**Source:** Direct testing on M4 MacBook Pro, January 2026

---

## Critical: CGEvent vs NSEvent for Reading data1

**Important discovery (January 2026):** Reading NX_SYSDEFINED event data directly from CGEvent gives incorrect/inconsistent results.

### The Problem

Using `CGEvent.getIntegerValueField(CGEventField(rawValue: 85)!)` to read data1 produces **incorrect keyCodes that vary by frontmost application**:

| App | Observed keyCode | Expected |
|-----|------------------|----------|
| iTerm2 | 7 (MUTE) | 2 or 3 |
| Finder | 7 (MUTE) | 2 or 3 |
| VSCode | 9 (unknown) | 2 or 3 |
| Activity Monitor | 20 (REWIND) | 2 or 3 |

This led to incorrect assumptions that M4 Macs send different keyCodes depending on the foreground app.

### The Solution

Convert CGEvent to NSEvent first, then read data1:

```swift
// WRONG - gives inconsistent results
let data1 = event.getIntegerValueField(CGEventField(rawValue: 85)!)

// CORRECT - always gives accurate keyCodes
if let nsEvent = NSEvent(cgEvent: event) {
    let subtype = nsEvent.subtype.rawValue
    guard subtype == 8 else { return }  // Only process media keys (NX_SUBTYPE_AUX_CONTROL_BUTTONS)

    let data1 = nsEvent.data1
    let keyCode = Int((data1 >> 16) & 0xFF)  // Now correctly returns 2 or 3
}
```

### Verification

With NSEvent conversion, brightness keys consistently report correct keyCodes across ALL apps:

```
iTerm2:          kc=2=BRIGHTNESS_UP, kc=3=BRIGHTNESS_DOWN
Preview:         kc=2=BRIGHTNESS_UP, kc=3=BRIGHTNESS_DOWN
Rancher Desktop: kc=2=BRIGHTNESS_UP, kc=3=BRIGHTNESS_DOWN
Firefox:         kc=2=BRIGHTNESS_UP, kc=3=BRIGHTNESS_DOWN
Finder:          kc=2=BRIGHTNESS_UP, kc=3=BRIGHTNESS_DOWN
Sublime Text:    kc=2=BRIGHTNESS_UP, kc=3=BRIGHTNESS_DOWN
```

### Why This Matters

1. **Simplified configuration**: Only need to check keyCodes 2 and 3, not a long list of app-specific codes
2. **Correct subtype filtering**: Can properly filter for subtype 8 (media keys) vs subtype 7 (mouse buttons)
3. **Reliable detection**: Works consistently regardless of which app is frontmost

**Source:** Direct testing on M4 MacBook Pro with test-keytypes diagnostic tool, January 2026

---

## Debugging Journey: What We Tried

This section documents the investigation process for future reference.

### Initial Symptom

Brightness sync only worked in some apps. When using a diagnostic tool to log keyCode values, we observed different keyCodes depending on which app was frontmost:

- iTerm2/Finder: keyCode 7 (MUTE)
- VSCode/Signal: keyCode 9 (unknown)
- Activity Monitor: keyCode 20 (REWIND)
- System Settings: keyCode 21 (ILLUMINATION_UP)

This led to the incorrect hypothesis that M4 Macs send different brightness keyCodes depending on the foreground app.

### What We Tried (Didn't Work)

1. **Adding all observed keyCodes to the allow list** - We added [2, 3, 6, 7, 9, 19, 20, 21] as valid brightness keyCodes. This was a workaround that masked the real problem.

2. **Checking if apps were intercepting events** - We investigated whether apps like Spotify's SPMediaKeyTap were consuming brightness events. They weren't - brightness keys (2, 3) are explicitly NOT intercepted by media key handlers.

3. **Looking at Karabiner-Elements source** - Karabiner uses HID at the driver level, not CGEventTap for media keys. Different architecture, not directly applicable.

### The Breakthrough

We looked at Chromium's implementation and noticed they convert CGEvent to NSEvent before reading data1. When we tested this approach:

```swift
// Before: Inconsistent keyCodes by app
let data1 = event.getIntegerValueField(CGEventField(rawValue: 85)!)

// After: Consistent keyCodes (2 and 3) across all apps
if let nsEvent = NSEvent(cgEvent: event) {
    let data1 = nsEvent.data1
}
```

### Root Cause

`CGEvent.getIntegerValueField(CGEventField(rawValue: 85)!)` returns **garbage data** for NX_SYSDEFINED events. The field index 85 is not the correct way to access data1 for these event types.

NSEvent correctly interprets the event structure and provides accurate data1 values.

### Lesson Learned

When debugging macOS event handling:
1. Don't trust CGEvent field access for NX_SYSDEFINED events
2. Always convert to NSEvent for reliable data extraction
3. Check subtype to filter event categories (8 = media keys, 7 = mouse buttons)
4. Look at how established projects (Chromium, Firefox) handle the same events
