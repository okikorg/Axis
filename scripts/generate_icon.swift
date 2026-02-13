#!/usr/bin/env swift

import AppKit
import Foundation

// --- Configuration ---
let bgColor = NSColor(red: 0x12/255.0, green: 0x12/255.0, blue: 0x12/255.0, alpha: 1.0)
let fgColor = NSColor(red: 0xe8/255.0, green: 0xe8/255.0, blue: 0xe8/255.0, alpha: 1.0)
let cornerRadiusFraction: CGFloat = 0.22 // macOS-style rounded rect

let rootDir = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()   // scripts/
    .deletingLastPathComponent()   // project root
let resourcesDir = rootDir.appendingPathComponent("Resources")

// Try to load the bundled Roboto Mono font
let fontsDir = rootDir.appendingPathComponent("Sources/Axis/Resources/Fonts")
let robotoMonoBoldPath = fontsDir.appendingPathComponent("RobotoMono-Bold.ttf")
if FileManager.default.fileExists(atPath: robotoMonoBoldPath.path) {
    CTFontManagerRegisterFontsForURL(robotoMonoBoldPath as CFURL, .process, nil)
}

// Required .iconset sizes: name -> pixel size
let iconSizes: [(String, Int)] = [
    ("icon_16x16",       16),
    ("icon_16x16@2x",    32),
    ("icon_32x32",       32),
    ("icon_32x32@2x",    64),
    ("icon_128x128",    128),
    ("icon_128x128@2x", 256),
    ("icon_256x256",    256),
    ("icon_256x256@2x", 512),
    ("icon_512x512",    512),
    ("icon_512x512@2x",1024),
]

func renderIcon(size: Int) -> NSImage {
    let s = CGFloat(size)
    let image = NSImage(size: NSSize(width: s, height: s))
    image.lockFocus()

    guard NSGraphicsContext.current?.cgContext != nil else {
        fatalError("No graphics context")
    }

    // Background rounded rect
    let rect = NSRect(x: 0, y: 0, width: s, height: s)
    let cornerRadius = s * cornerRadiusFraction
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    bgColor.setFill()
    bgPath.fill()

    // --- Geometry (from Resources/icon.svg, converted to CG coords) ---
    let pad = s * 0.1625

    // X line endpoints
    let topLeft     = CGPoint(x: pad,     y: s - pad)
    let topRight    = CGPoint(x: s - pad, y: s - pad)
    let bottomLeft  = CGPoint(x: pad,     y: pad)
    let bottomRight = CGPoint(x: s - pad, y: pad)

    // Triangle vertices — apex at center, base below
    let triApex      = CGPoint(x: s * 0.5,   y: s * 0.5)
    let triBaseLeft  = CGPoint(x: s * 0.246,  y: s * 0.277)
    let triBaseRight = CGPoint(x: s * 0.754,  y: s * 0.277)

    // --- 1. Triangle (behind X) ---
    fgColor.setFill()
    let tri = NSBezierPath()
    tri.move(to: triApex)
    tri.line(to: triBaseLeft)
    tri.line(to: triBaseRight)
    tri.close()
    tri.fill()

    // --- 2. X lines (on top) ---
    let lineWidth = max(s * 0.0586, 1.0)
    fgColor.setStroke()

    let xPath = NSBezierPath()
    xPath.lineWidth = lineWidth
    xPath.lineCapStyle = .round

    xPath.move(to: topLeft);  xPath.line(to: bottomRight)   // top-left → bottom-right
    xPath.move(to: topRight); xPath.line(to: bottomLeft)    // top-right → bottom-left

    xPath.stroke()

    image.unlockFocus()
    return image
}

func pngData(from image: NSImage) -> Data {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Failed to create PNG data")
    }
    return png
}

// --- Main ---
let iconsetDir = resourcesDir.appendingPathComponent("AppIcon.iconset")
let icnsPath = resourcesDir.appendingPathComponent("AppIcon.icns")

// Create Resources/ and iconset directory
try FileManager.default.createDirectory(at: iconsetDir, withIntermediateDirectories: true)

print("Generating icon images...")
for (name, size) in iconSizes {
    let image = renderIcon(size: size)
    let data = pngData(from: image)
    let filePath = iconsetDir.appendingPathComponent("\(name).png")
    try data.write(to: filePath)
    print("  \(name).png (\(size)x\(size))")
}

print("Converting to .icns...")
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetDir.path, "-o", icnsPath.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    fatalError("iconutil failed with status \(process.terminationStatus)")
}

// Clean up the .iconset directory
try FileManager.default.removeItem(at: iconsetDir)

print("Icon generated: \(icnsPath.path)")
