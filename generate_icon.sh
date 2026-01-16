#!/bin/bash
# Generate app icon for KeyboardBrightnessSync
# Creates an icon with sun (brightness) on left and K (keyboard) on right

set -e

OUTPUT_ICNS="${1:-AppIcon.icns}"
TEMP_DIR=$(mktemp -d)
ICONSET_DIR="$TEMP_DIR/AppIcon.iconset"

mkdir -p "$ICONSET_DIR"

# Create icon using Swift
swift - << 'SWIFT_CODE'
import AppKit
import CoreGraphics

func createIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let context = NSGraphicsContext.current!.cgContext

    // Background - rounded rectangle with gradient
    let bgRect = CGRect(x: size * 0.05, y: size * 0.05, width: size * 0.9, height: size * 0.9)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: size * 0.2, cornerHeight: size * 0.2, transform: nil)

    // Gradient background (dark blue to lighter blue)
    let colors = [
        CGColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1.0),
        CGColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1.0)
    ]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0.0, 1.0])!

    context.saveGState()
    context.addPath(bgPath)
    context.clip()
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size, y: size), options: [])
    context.restoreGState()

    // Draw sun on left side (brightness symbol)
    let sunCenterX = size * 0.32
    let sunCenterY = size * 0.5
    let sunRadius = size * 0.15
    let rayLength = size * 0.08

    // Sun body
    context.setFillColor(CGColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0))
    context.addArc(center: CGPoint(x: sunCenterX, y: sunCenterY), radius: sunRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
    context.fillPath()

    // Sun rays
    context.setStrokeColor(CGColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0))
    context.setLineWidth(size * 0.025)
    context.setLineCap(.round)

    for i in 0..<8 {
        let angle = CGFloat(i) * .pi / 4
        let innerRadius = sunRadius + size * 0.03
        let outerRadius = sunRadius + rayLength

        let startX = sunCenterX + cos(angle) * innerRadius
        let startY = sunCenterY + sin(angle) * innerRadius
        let endX = sunCenterX + cos(angle) * outerRadius
        let endY = sunCenterY + sin(angle) * outerRadius

        context.move(to: CGPoint(x: startX, y: startY))
        context.addLine(to: CGPoint(x: endX, y: endY))
    }
    context.strokePath()

    // Draw divider line
    context.setStrokeColor(CGColor(red: 0.5, green: 0.6, blue: 0.8, alpha: 0.5))
    context.setLineWidth(size * 0.015)
    context.move(to: CGPoint(x: size * 0.5, y: size * 0.25))
    context.addLine(to: CGPoint(x: size * 0.5, y: size * 0.75))
    context.strokePath()

    // Draw "K" on right side (keyboard)
    let kCenterX = size * 0.68
    let kCenterY = size * 0.5
    let kHeight = size * 0.35
    let kWidth = size * 0.22

    context.setStrokeColor(CGColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 1.0))
    context.setLineWidth(size * 0.05)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    // K vertical line
    context.move(to: CGPoint(x: kCenterX - kWidth * 0.4, y: kCenterY - kHeight / 2))
    context.addLine(to: CGPoint(x: kCenterX - kWidth * 0.4, y: kCenterY + kHeight / 2))
    context.strokePath()

    // K diagonal lines
    context.move(to: CGPoint(x: kCenterX + kWidth * 0.5, y: kCenterY - kHeight / 2))
    context.addLine(to: CGPoint(x: kCenterX - kWidth * 0.4, y: kCenterY))
    context.addLine(to: CGPoint(x: kCenterX + kWidth * 0.5, y: kCenterY + kHeight / 2))
    context.strokePath()

    image.unlockFocus()
    return image
}

func savePNG(image: NSImage, to path: String, size: Int) {
    let resizedImage = NSImage(size: NSSize(width: size, height: size))
    resizedImage.lockFocus()
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    resizedImage.unlockFocus()

    guard let tiffData = resizedImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        return
    }

    try? pngData.write(to: URL(fileURLWithPath: path))
}

// Generate icons at all required sizes
let sizes = [16, 32, 64, 128, 256, 512, 1024]
let icon = createIcon(size: 1024)

let tempDir = ProcessInfo.processInfo.environment["TEMP_DIR"] ?? "/tmp"
let iconsetDir = "\(tempDir)/AppIcon.iconset"

for size in sizes {
    savePNG(image: icon, to: "\(iconsetDir)/icon_\(size)x\(size).png", size: size)
    if size <= 512 {
        savePNG(image: icon, to: "\(iconsetDir)/icon_\(size)x\(size)@2x.png", size: size * 2)
    }
}

print("Icons generated in \(iconsetDir)")
SWIFT_CODE

# Export TEMP_DIR for Swift script
export TEMP_DIR="$TEMP_DIR"

# Re-run with environment variable
swift - << SWIFT_CODE
import AppKit
import CoreGraphics

func createIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let context = NSGraphicsContext.current!.cgContext

    // Background - rounded rectangle with gradient
    let bgRect = CGRect(x: size * 0.05, y: size * 0.05, width: size * 0.9, height: size * 0.9)
    let bgPath = CGPath(roundedRect: bgRect, cornerWidth: size * 0.2, cornerHeight: size * 0.2, transform: nil)

    // Gradient background (dark blue to lighter blue)
    let colors = [
        CGColor(red: 0.1, green: 0.1, blue: 0.3, alpha: 1.0),
        CGColor(red: 0.2, green: 0.3, blue: 0.5, alpha: 1.0)
    ]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: [0.0, 1.0])!

    context.saveGState()
    context.addPath(bgPath)
    context.clip()
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: size, y: size), options: [])
    context.restoreGState()

    // Draw sun on left side (brightness symbol)
    let sunCenterX = size * 0.32
    let sunCenterY = size * 0.5
    let sunRadius = size * 0.15
    let rayLength = size * 0.08

    // Sun body
    context.setFillColor(CGColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0))
    context.addArc(center: CGPoint(x: sunCenterX, y: sunCenterY), radius: sunRadius, startAngle: 0, endAngle: .pi * 2, clockwise: true)
    context.fillPath()

    // Sun rays
    context.setStrokeColor(CGColor(red: 1.0, green: 0.85, blue: 0.3, alpha: 1.0))
    context.setLineWidth(size * 0.025)
    context.setLineCap(.round)

    for i in 0..<8 {
        let angle = CGFloat(i) * .pi / 4
        let innerRadius = sunRadius + size * 0.03
        let outerRadius = sunRadius + rayLength

        let startX = sunCenterX + cos(angle) * innerRadius
        let startY = sunCenterY + sin(angle) * innerRadius
        let endX = sunCenterX + cos(angle) * outerRadius
        let endY = sunCenterY + sin(angle) * outerRadius

        context.move(to: CGPoint(x: startX, y: startY))
        context.addLine(to: CGPoint(x: endX, y: endY))
    }
    context.strokePath()

    // Draw divider line
    context.setStrokeColor(CGColor(red: 0.5, green: 0.6, blue: 0.8, alpha: 0.5))
    context.setLineWidth(size * 0.015)
    context.move(to: CGPoint(x: size * 0.5, y: size * 0.25))
    context.addLine(to: CGPoint(x: size * 0.5, y: size * 0.75))
    context.strokePath()

    // Draw "K" on right side (keyboard)
    let kCenterX = size * 0.68
    let kCenterY = size * 0.5
    let kHeight = size * 0.35
    let kWidth = size * 0.22

    context.setStrokeColor(CGColor(red: 0.9, green: 0.9, blue: 1.0, alpha: 1.0))
    context.setLineWidth(size * 0.05)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    // K vertical line
    context.move(to: CGPoint(x: kCenterX - kWidth * 0.4, y: kCenterY - kHeight / 2))
    context.addLine(to: CGPoint(x: kCenterX - kWidth * 0.4, y: kCenterY + kHeight / 2))
    context.strokePath()

    // K diagonal lines
    context.move(to: CGPoint(x: kCenterX + kWidth * 0.5, y: kCenterY - kHeight / 2))
    context.addLine(to: CGPoint(x: kCenterX - kWidth * 0.4, y: kCenterY))
    context.addLine(to: CGPoint(x: kCenterX + kWidth * 0.5, y: kCenterY + kHeight / 2))
    context.strokePath()

    image.unlockFocus()
    return image
}

func savePNG(image: NSImage, to path: String, size: Int) {
    let resizedImage = NSImage(size: NSSize(width: size, height: size))
    resizedImage.lockFocus()
    image.draw(in: NSRect(x: 0, y: 0, width: size, height: size))
    resizedImage.unlockFocus()

    guard let tiffData = resizedImage.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        return
    }

    try? pngData.write(to: URL(fileURLWithPath: path))
}

// Generate icons at all required sizes
let sizes = [16, 32, 64, 128, 256, 512, 1024]
let icon = createIcon(size: 1024)

let iconsetDir = "$ICONSET_DIR"

for size in sizes {
    savePNG(image: icon, to: "\(iconsetDir)/icon_\(size)x\(size).png", size: size)
    if size <= 512 {
        savePNG(image: icon, to: "\(iconsetDir)/icon_\(size)x\(size)@2x.png", size: size * 2)
    }
}

print("Icons generated")
SWIFT_CODE

# Convert iconset to icns
iconutil -c icns "$ICONSET_DIR" -o "$OUTPUT_ICNS"

# Cleanup
rm -rf "$TEMP_DIR"

echo "Icon created: $OUTPUT_ICNS"
