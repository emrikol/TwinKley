#!/usr/bin/env swift

// =============================================================================
// test-keytypes.swift - Brightness Key Diagnostic Tool
// =============================================================================
//
// Monitors macOS keyboard events and NX_SYSDEFINED media key events in real-time.
// Essential for debugging brightness key detection issues.
//
// USAGE:
//   swift scripts/test-keytypes.swift
//
// REQUIREMENTS:
//   - Accessibility permission (System Settings > Privacy & Security > Accessibility)
//
// OUTPUT FORMAT:
//   [time] #count NX(sub=SUBTYPE,kc=KEYCODE=NAME,STATE,d2=DATA2) | APP | SEC | D:XX% K:XX%
//
//   - sub: Event subtype (8 = media keys, 7 = mouse buttons)
//   - kc: Key code (2=BRIGHTNESS_UP, 3=BRIGHTNESS_DOWN, etc.)
//   - STATE: D=Down, U=Up, R=Repeat
//   - APP: Frontmost application
//   - SEC: Secure input status (SEC=active, ---=inactive)
//   - D/K: Display and Keyboard brightness percentages
//
// KEY INSIGHT:
//   This tool uses NSEvent(cgEvent:) to read event data correctly.
//   Using CGEvent.getIntegerValueField directly gives WRONG results!
//   See docs/macos-media-keys-reference.md for details.
//
// =============================================================================

import Foundation
import CoreGraphics
import AppKit

// MARK: - Globals for callback access

var gStartTime = Date()
var gEventCount = 0

// Brightness functions
let dsPath = "/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices"
let dsHandle = dlopen(dsPath, RTLD_NOW)!
typealias DSGetFunc = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
let gDsGet = unsafeBitCast(dlsym(dsHandle, "DisplayServicesGetBrightness"), to: DSGetFunc.self)

let cbPath = "/System/Library/PrivateFrameworks/CoreBrightness.framework/CoreBrightness"
let _ = dlopen(cbPath, RTLD_NOW)
let gKbClass = NSClassFromString("KeyboardBrightnessClient") as? NSObject.Type
var gKbClient: NSObject? = nil
let gKbSel = NSSelectorFromString("brightnessForKeyboard:")
typealias KBGetFunc = @convention(c) (AnyObject, Selector, UInt64) -> Float
let gKbGet = unsafeBitCast(dlsym(dlopen(nil, RTLD_NOW), "objc_msgSend"), to: KBGetFunc.self)

// Secure input check
typealias IsSecureFunc = @convention(c) () -> Bool
var gSecureCheck: IsSecureFunc? = nil

let keyTypeNames: [Int: String] = [
    0: "SOUND_UP", 1: "SOUND_DOWN", 2: "BRIGHTNESS_UP", 3: "BRIGHTNESS_DOWN",
    6: "POWER", 7: "MUTE", 16: "PLAY", 17: "NEXT", 18: "PREVIOUS",
    19: "FAST", 20: "REWIND", 21: "ILLUM_UP", 22: "ILLUM_DOWN", 23: "ILLUM_TOGGLE",
]

// MARK: - Main

print("=== Brightness Key Diagnostic Tool ===\n")

// Initialize keyboard client
gKbClient = gKbClass?.init()

// Initialize secure input check
if let carbon = dlopen("/System/Library/Frameworks/Carbon.framework/Carbon", RTLD_NOW),
   let sym = dlsym(carbon, "IsSecureEventInputEnabled") {
    gSecureCheck = unsafeBitCast(sym, to: IsSecureFunc.self)
}

// Helper functions that don't capture
func getDisplayB() -> Float {
    var b: Float = 0
    _ = gDsGet(CGMainDisplayID(), &b)
    return b
}

func getKeyboardB() -> Float {
    guard let client = gKbClient else { return -1 }
    return gKbGet(client, gKbSel, 0)
}

func getSecure() -> Bool {
    return gSecureCheck?() ?? false
}

func getApp() -> String {
    return NSWorkspace.shared.frontmostApplication?.localizedName ?? "?"
}

// Callback
let callback: CGEventTapCallBack = { _, type, event, _ in
    if type == .tapDisabledByTimeout {
        print("[TAP TIMEOUT]")
        return Unmanaged.passUnretained(event)
    }

    gEventCount += 1
    let elapsed = Date().timeIntervalSince(gStartTime)

    var info = ""

    if type == .keyDown {
        let kc = event.getIntegerValueField(.keyboardEventKeycode)
        info = "KeyDown(\(kc))"
    } else if type == .keyUp {
        let kc = event.getIntegerValueField(.keyboardEventKeycode)
        info = "KeyUp(\(kc))"
    } else if type.rawValue == 14 {
        // Convert to NSEvent to get subtype
        if let nsEvent = NSEvent(cgEvent: event) {
            let subtype = nsEvent.subtype.rawValue
            let data1 = nsEvent.data1
            let data2 = nsEvent.data2
            let keyCode = Int((data1 >> 16) & 0xFF)
            let keyState = Int((data1 >> 8) & 0xFF)
            let name = keyTypeNames[keyCode] ?? "?"
            let st = (keyState & 0xF0) == 0xA0 ? "D" : (keyState & 0xF0) == 0xB0 ? "U" : "R"
            info = "NX(sub=\(subtype),kc=\(keyCode)=\(name),\(st),d2=\(data2))"
        } else {
            // Fallback to raw CGEvent
            let data1 = event.getIntegerValueField(CGEventField(rawValue: 85)!)
            let keyCode = Int((data1 >> 16) & 0xFF)
            info = "NX(raw,kc=\(keyCode))"
        }
    }

    let app = getApp()
    let sec = getSecure() ? "SEC" : "---"
    let dB = getDisplayB()
    let kB = getKeyboardB()

    print(String(format: "[%.1fs] #%d %@ | %@ | %@ | D:%.0f%% K:%.0f%%",
                 elapsed, gEventCount, info, app, sec, dB*100, kB*100))

    return Unmanaged.passUnretained(event)
}

// Setup tap
let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue) |
                        (1 << 14)

guard let tap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: mask,
    callback: callback,
    userInfo: nil
) else {
    print("ERROR: No tap. Check Accessibility permissions.")
    exit(1)
}

let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

print("Monitoring... Press Ctrl+C to stop.\n")
print("App: \(getApp()) | Secure: \(getSecure()) | Display: \(Int(getDisplayB()*100))% | KB: \(Int(getKeyboardB()*100))%")
print("")

gStartTime = Date()
CFRunLoopRun()
