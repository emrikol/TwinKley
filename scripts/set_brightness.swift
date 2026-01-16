#!/usr/bin/env swift
// Test script to change display brightness programmatically
// Usage: swift set_brightness.swift [brightness 0.0-1.0]

import Foundation
import CoreGraphics

typealias GetBrightnessFunc = @convention(c) (UInt32, UnsafeMutablePointer<Float>) -> Int32
typealias SetBrightnessFunc = @convention(c) (UInt32, Float) -> Int32

guard let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_NOW) else {
    print("Failed to load DisplayServices")
    exit(1)
}

guard let getSym = dlsym(handle, "DisplayServicesGetBrightness"),
      let setSym = dlsym(handle, "DisplayServicesSetBrightness") else {
    print("Failed to get symbols")
    exit(1)
}

let getFunc = unsafeBitCast(getSym, to: GetBrightnessFunc.self)
let setFunc = unsafeBitCast(setSym, to: SetBrightnessFunc.self)

let displayID = CGMainDisplayID()
var brightness: Float = 0

if getFunc(displayID, &brightness) == 0 {
    print("Current brightness: \(Int(brightness * 100))%")

    // If argument provided, set to that value; otherwise toggle
    let newBrightness: Float
    if CommandLine.arguments.count > 1, let value = Float(CommandLine.arguments[1]) {
        newBrightness = min(1.0, max(0.0, value))
    } else {
        // Toggle up or down by 10%
        newBrightness = brightness > 0.5 ? brightness - 0.1 : brightness + 0.1
    }

    let result = setFunc(displayID, newBrightness)
    print("Set brightness to \(Int(newBrightness * 100))%: \(result == 0 ? "OK" : "FAILED")")
} else {
    print("Failed to get brightness")
    exit(1)
}
