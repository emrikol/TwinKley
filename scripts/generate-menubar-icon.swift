#!/usr/bin/env swift
// Generates the TwinKley menu bar icon as a PDF file
// Usage: swift scripts/generate-menubar-icon.swift output.pdf

import AppKit

func createMenuBarIcon() -> NSImage {
	let size: CGFloat = 18
	let image = NSImage(size: NSSize(width: size, height: size))

	image.lockFocus()
	let context = NSGraphicsContext.current!.cgContext

	// Use black color - template mode will handle light/dark
	context.setFillColor(NSColor.black.cgColor)
	context.setStrokeColor(NSColor.black.cgColor)

	// Sun on left half (centered at 35%)
	let sunCenterX = size * 0.35
	let sunCenterY = size * 0.5
	let sunRadius = size * 0.14

	// Sun body
	context.addArc(
		center: CGPoint(x: sunCenterX, y: sunCenterY),
		radius: sunRadius,
		startAngle: 0,
		endAngle: .pi * 2,
		clockwise: true
	)
	context.fillPath()

	// Sun rays
	context.setLineWidth(size / 14)
	context.setLineCap(.round)
	let rayLength = size * 0.12
	let rayStart = sunRadius + size / 22

	for i in 0..<8 {
		let angle = CGFloat(i) * .pi / 4
		context.move(to: CGPoint(x: sunCenterX + cos(angle) * rayStart, y: sunCenterY + sin(angle) * rayStart))
		context.addLine(to: CGPoint(
			x: sunCenterX + cos(angle) * (rayStart + rayLength),
			y: sunCenterY + sin(angle) * (rayStart + rayLength)
		))
	}
	context.strokePath()

	// "K" on right half (centered at 68%)
	let kCenterX = size * 0.68
	let kCenterY = size * 0.5
	let kHeight = size * 0.65
	let kWidth = size * 0.28

	context.setLineWidth(size / 9)
	context.setLineCap(.round)
	context.setLineJoin(.round)

	// K vertical line
	let kLeftX = kCenterX - kWidth * 0.3
	context.move(to: CGPoint(x: kLeftX, y: kCenterY - kHeight / 2))
	context.addLine(to: CGPoint(x: kLeftX, y: kCenterY + kHeight / 2))
	context.strokePath()

	// K diagonal lines
	let kRightX = kCenterX + kWidth * 0.5
	context.move(to: CGPoint(x: kRightX, y: kCenterY - kHeight / 2))
	context.addLine(to: CGPoint(x: kLeftX, y: kCenterY))
	context.addLine(to: CGPoint(x: kRightX, y: kCenterY + kHeight / 2))
	context.strokePath()

	image.unlockFocus()

	image.isTemplate = true
	return image
}

// Main
guard CommandLine.arguments.count > 1 else {
	print("Usage: generate-menubar-icon.swift <output.pdf>")
	exit(1)
}

let outputPath = CommandLine.arguments[1]
let image = createMenuBarIcon()

// Convert to PDF
guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff) else {
	print("Error: Failed to create bitmap")
	exit(1)
}

let pdfData = NSMutableData()
let consumer = CGDataConsumer(data: pdfData as CFMutableData)!
var rect = CGRect(x: 0, y: 0, width: 18, height: 18)
let pdfContext = CGContext(consumer: consumer, mediaBox: &rect, nil)!

pdfContext.beginPDFPage(nil)
if let cgImage = bitmap.cgImage {
	pdfContext.draw(cgImage, in: rect)
}
pdfContext.endPDFPage()
pdfContext.closePDF()

try! pdfData.write(toFile: outputPath, atomically: true)
print("Generated menu bar icon: \(outputPath)")
