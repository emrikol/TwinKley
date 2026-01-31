#!/usr/bin/env swift

// =============================================================================
// test-nx-events.swift - NX_SYSDEFINED Event Posting Test
// =============================================================================
//
// Posts synthetic NX_SYSDEFINED events to test which keyCodes affect brightness.
// Useful for verifying keyCode behavior without physical key presses.
//
// USAGE:
//   swift scripts/test-nx-events.swift
//
// NOTE:
//   Synthetic events may not affect system brightness the same way physical
//   keys do. The system may ignore or handle them differently.
//
// SEE ALSO:
//   - test-keytypes.swift: Monitor real events from physical keys
//   - docs/macos-media-keys-reference.md: NX_KEYTYPE constants and event structure
//
// =============================================================================

import Foundation
import CoreGraphics

print("=== NX_SYSDEFINED Event Test ===\n")

// Brightness reading
let dsPath = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
let dsHandle = dlopen(dsPath, RTLD_NOW)!
typealias DSGetFunc = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
let dsGet = unsafeBitCast(dlsym(dsHandle, "DisplayServicesGetBrightness"), to: DSGetFunc.self)

func getDisplayBrightness() -> Float {
    var b: Float = 0
    _ = dsGet(CGMainDisplayID(), &b)
    return b
}

// Post NX_SYSDEFINED event using CGEvent
func postNXEvent(keyCode: Int, keyDown: Bool) {
    // Create a system-defined event
    // NX_SYSDEFINED = 14
    guard let event = CGEvent(source: nil) else {
        print("  Failed to create event")
        return
    }

    // Set event type to NX_SYSDEFINED (14)
    event.type = CGEventType(rawValue: 14)!

    // Build data1: keyCode in bits 16-23, keyState in bits 8-15
    let keyState = keyDown ? 0x0A : 0x0B
    let data1 = (keyCode << 16) | (keyState << 8)

    // Set the data1 field (field 85 = kCGEventSourceStatePrivate... actually it's misc field)
    event.setIntegerValueField(CGEventField(rawValue: 85)!, value: Int64(data1))

    // Post the event
    event.post(tap: .cgSessionEventTap)
}

// Test a keyCode
func testKeyCode(_ code: Int, _ name: String) {
    let before = getDisplayBrightness()

    // Post key down then key up
    postNXEvent(keyCode: code, keyDown: true)
    Thread.sleep(forTimeInterval: 0.05)
    postNXEvent(keyCode: code, keyDown: false)
    Thread.sleep(forTimeInterval: 0.3)

    let after = getDisplayBrightness()
    let changed = abs(after - before) > 0.001

    if changed {
        print(String(format: "*** NX keyCode=%2d %-20s CHANGED: %.1f%% -> %.1f%%", code, name, before*100, after*100))
    } else {
        print(String(format: "    NX keyCode=%2d %-20s no change (%.1f%%)", code, name, before*100))
    }
}

print(String(format: "Starting brightness: %.1f%%\n", getDisplayBrightness() * 100))

// Test the official brightness keyCodes
print("--- Official Brightness KeyCodes ---")
testKeyCode(2, "BRIGHTNESS_UP")
testKeyCode(3, "BRIGHTNESS_DOWN")

print("\n--- Other Potentially Relevant KeyCodes ---")
testKeyCode(21, "ILLUMINATION_UP")
testKeyCode(22, "ILLUMINATION_DOWN")

// Skip dangerous ones: 6=POWER, 14=EJECT
print("\n--- Safe Media KeyCodes ---")
testKeyCode(7, "MUTE")
testKeyCode(16, "PLAY")
testKeyCode(19, "FAST")
testKeyCode(20, "REWIND")

print(String(format: "\nFinal brightness: %.1f%%", getDisplayBrightness() * 100))
print("\n=== Done ===")
