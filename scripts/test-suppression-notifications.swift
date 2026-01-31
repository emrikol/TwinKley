#!/usr/bin/env swift
//
// test-suppression-notifications.swift
// Diagnostic tool to discover CoreBrightness notification keys
//
// PURPOSE:
// This script attempts to discover if macOS CoreBrightness framework provides
// any notifications when the ambient light sensor changes keyboard backlight state.
// Currently, TwinKley polls for the "saturated" state because no reliable
// notification mechanism has been found. This script is for research purposes
// to potentially find a more efficient event-driven approach.
//
// BACKGROUND:
// When the ambient light sensor detects bright light (e.g., sunlight), macOS
// "locks" the keyboard backlight at minimum brightness. This state is called
// "saturated" in the CoreBrightness API (isBacklightSaturatedOnKeyboard:).
// TwinKley shows "Status: Locked" in the menu when this happens.
//
// The problem is there's no known notification for when this state changes.
// This script tries various notification registration methods to see if any
// of them fire when the ambient light sensor triggers suppression/saturation.
//
// WHAT IT TESTS:
// 1. KeyboardBrightnessClient.registerNotificationForKeys:keyboardID:block:
//    - Tries registering for various possible key names
// 2. BrightnessSystemClient.registerKeyboardNotificationCallbackBlock:
//    - General keyboard brightness callback
// 3. BrightnessSystemClient.registerNotificationBlock:
//    - General brightness notification callback
// 4. BrightnessSystemClient.registerNotificationForKeys:keyboardID:
//    - Key-based registration on BSC
// 5. Polling fallback (every 2 seconds) to detect changes even if notifications fail
//
// HOW TO USE:
// 1. Run in a DARK room (keyboard backlight should be ON and visible)
// 2. Execute: swift scripts/test-suppression-notifications.swift
// 3. Shine a bright flashlight at the ambient light sensor (near FaceTime camera)
// 4. Watch for "🔔 NOTIFICATION" messages - these indicate a notification fired
// 5. Watch for "⚡ POLL DETECTED" messages - these indicate polling caught a change
//    but no notification fired (meaning we still need polling for this)
//
// EXPECTED OUTCOME:
// If notifications work, you'll see 🔔 messages when shining the light.
// If only polling detects changes (⚡ messages), it confirms no notification exists
// and TwinKley must continue using polling for the "locked" state detection.
//
// FINDINGS (as of January 2026):
// No reliable notification has been found. The ambient light sensor state changes
// are not broadcast via any discovered CoreBrightness notification mechanism.
// TwinKley uses polling to detect the "saturated" state for menu status display.
//
// Usage: swift scripts/test-suppression-notifications.swift
//

import Foundation

let handle = dlopen("/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness", RTLD_NOW)
let msgSend = dlsym(dlopen(nil, RTLD_NOW), "objc_msgSend")!

// Possible notification key names to test
// These are educated guesses based on CoreBrightness API naming patterns
let possibleKeys: [String] = [
    // Direct property names (matching API method names)
    "BacklightSuppressed",
    "Suppressed",
    "suppressed",

    // CB-prefixed (CoreBrightness framework convention)
    "CBBacklightSuppressed",
    "CBKeyboardBacklightSuppressed",
    "CBSuppressed",

    // Keyboard-prefixed
    "KeyboardBacklightSuppressed",
    "KeyboardSuppressed",

    // k-prefixed constants (Apple constant naming convention)
    "kBacklightSuppressed",
    "kKeyboardBacklightSuppressed",

    // Other backlight states we know exist as methods
    "BacklightDimmed",
    "BacklightSaturated",
    "BacklightBrightness",
    "Brightness",
    "brightness",

    // Auto-brightness related (ambient light sensor)
    "AutoBrightness",
    "AutoBrightnessEnabled",
    "AmbientLightLevel",
    "AmbientEnabled",

    // Generic change notifications
    "BacklightState",
    "BacklightChanged",
    "KeyboardBacklightChanged",
    "StateChanged"
]

print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
print("CoreBrightness Notification Key Tester")
print("=" .padding(toLength: 60, withPad: "=", startingAt: 0))
print("")
print("Instructions:")
print("1. Run this in a DARK room (keyboard backlight should be ON)")
print("2. Shine a flashlight at the ambient light sensor (near FaceTime camera)")
print("3. Watch for '🔔 NOTIFICATION' messages below")
print("4. Note which key triggered the notification")
print("")
print("Press Ctrl+C to stop")
print("")

guard let kbcClass = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type,
      let bscClass = NSClassFromString("BrightnessSystemClient") as? NSObject.Type else {
    print("❌ Failed to load CoreBrightness classes")
    exit(1)
}

let kbClient = kbcClass.init()
let bscClient = bscClass.init()

guard let ids = kbClient.perform(Selector(("copyKeyboardBacklightIDs")))?.takeUnretainedValue() as? [UInt64],
      let kbID = ids.first else {
    print("❌ Failed to get keyboard ID")
    exit(1)
}

print("Keyboard ID: \(kbID)")
print("")

// Helper to check current keyboard backlight state
func printCurrentState() {
    typealias BoolFunc = @convention(c) (AnyObject, Selector, UInt64) -> Bool
    typealias FloatFunc = @convention(c) (AnyObject, Selector, UInt64) -> Float

    let boolFn = unsafeBitCast(msgSend, to: BoolFunc.self)
    let floatFn = unsafeBitCast(msgSend, to: FloatFunc.self)

    let brightness = floatFn(kbClient, Selector(("brightnessForKeyboard:")), kbID)
    let suppressed = boolFn(kbClient, Selector(("isBacklightSuppressedOnKeyboard:")), kbID)
    let dimmed = boolFn(kbClient, Selector(("isBacklightDimmedOnKeyboard:")), kbID)
    let saturated = boolFn(kbClient, Selector(("isBacklightSaturatedOnKeyboard:")), kbID)

    let timestamp = ISO8601DateFormatter().string(from: Date())
    print("[\(timestamp)] Brightness: \(String(format: "%.2f", brightness)) | Suppressed: \(suppressed) | Dimmed: \(dimmed) | Saturated: \(saturated)")
}

print("Current state:")
printCurrentState()
print("")

// Method 1: KeyboardBrightnessClient registerNotificationForKeys:keyboardID:block:
print("Registering with KeyboardBrightnessClient...")
let kbCallback: @convention(block) (NSString?, Any?) -> Void = { key, value in
    print("🔔 NOTIFICATION (KBC)! Key: \(key ?? "nil"), Value: \(String(describing: value))")
    printCurrentState()
}

typealias KBRegFunc = @convention(c) (AnyObject, Selector, NSArray, UInt64, Any) -> Void
let kbRegFn = unsafeBitCast(msgSend, to: KBRegFunc.self)
kbRegFn(kbClient, Selector(("registerNotificationForKeys:keyboardID:block:")), possibleKeys as NSArray, kbID, kbCallback)

// Method 2: BrightnessSystemClient registerKeyboardNotificationCallbackBlock:
print("Registering with BrightnessSystemClient (keyboard callback)...")
let bscKbCallback: @convention(block) () -> Void = {
    print("🔔 NOTIFICATION (BSC-KB)! Keyboard callback fired")
    printCurrentState()
}
typealias BSCRegFunc = @convention(c) (AnyObject, Selector, Any) -> Void
let bscRegFn = unsafeBitCast(msgSend, to: BSCRegFunc.self)
bscRegFn(bscClient, Selector(("registerKeyboardNotificationCallbackBlock:")), bscKbCallback)

// Method 3: BrightnessSystemClient registerNotificationBlock:
print("Registering with BrightnessSystemClient (general callback)...")
let bscGenCallback: @convention(block) () -> Void = {
    print("🔔 NOTIFICATION (BSC-GEN)! General callback fired")
    printCurrentState()
}
bscRegFn(bscClient, Selector(("registerNotificationBlock:")), bscGenCallback)

// Method 4: BrightnessSystemClient registerNotificationForKeys:keyboardID:
print("Registering with BrightnessSystemClient for specific keys...")
typealias BSCKeysRegFunc = @convention(c) (AnyObject, Selector, NSArray, UInt64) -> Void
let bscKeysRegFn = unsafeBitCast(msgSend, to: BSCKeysRegFunc.self)
bscKeysRegFn(bscClient, Selector(("registerNotificationForKeys:keyboardID:")), possibleKeys as NSArray, kbID)

print("")
print("✓ All notification handlers registered")
print("✓ Testing \(possibleKeys.count) possible key names")
print("")
print("Monitoring... (polling state every 2 seconds as backup)")
print("-" .padding(toLength: 60, withPad: "-", startingAt: 0))

// Polling fallback - detects changes even if no notifications fire
// If we only see ⚡ messages and no 🔔 messages, it means notifications don't work
var lastSuppressed = false
var lastBrightness: Float = -1

typealias BoolFunc = @convention(c) (AnyObject, Selector, UInt64) -> Bool
typealias FloatFunc = @convention(c) (AnyObject, Selector, UInt64) -> Float
let boolFn = unsafeBitCast(msgSend, to: BoolFunc.self)
let floatFn = unsafeBitCast(msgSend, to: FloatFunc.self)

// Capture initial state
lastSuppressed = boolFn(kbClient, Selector(("isBacklightSuppressedOnKeyboard:")), kbID)
lastBrightness = floatFn(kbClient, Selector(("brightnessForKeyboard:")), kbID)

Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
    let suppressed = boolFn(kbClient, Selector(("isBacklightSuppressedOnKeyboard:")), kbID)
    let brightness = floatFn(kbClient, Selector(("brightnessForKeyboard:")), kbID)

    if suppressed != lastSuppressed {
        print("⚡ POLL DETECTED: Suppression changed: \(lastSuppressed) -> \(suppressed)")
        printCurrentState()
        lastSuppressed = suppressed
    }

    if abs(brightness - lastBrightness) > 0.01 {
        print("⚡ POLL DETECTED: Brightness changed: \(String(format: "%.2f", lastBrightness)) -> \(String(format: "%.2f", brightness))")
        lastBrightness = brightness
    }
}

// Run forever until Ctrl+C
RunLoop.current.run()
