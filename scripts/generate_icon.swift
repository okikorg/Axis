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

    // Background rounded rect — inset to match macOS icon grid
    let inset = s * 0.05
    let rect = NSRect(x: inset, y: inset, width: s - inset * 2, height: s - inset * 2)
    let cornerRadius = (s - inset * 2) * cornerRadiusFraction
    let bgPath = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    bgColor.setFill()
    bgPath.fill()

    // Subtle border (like Ghostty / Activity Monitor)
    let borderColor = NSColor(white: 1.0, alpha: 0.15)
    borderColor.setStroke()
    bgPath.lineWidth = max(s * 0.006, 0.5)
    bgPath.stroke()

    // --- Geometry (from Resources/icon.svg, scaled to fit inset rect) ---
    let inner = s - inset * 2
    let pad = inner * 0.1625

    // X line endpoints (relative to inset origin)
    let topLeft     = CGPoint(x: inset + pad,         y: inset + inner - pad)
    let topRight    = CGPoint(x: inset + inner - pad,  y: inset + inner - pad)
    let bottomLeft  = CGPoint(x: inset + pad,         y: inset + pad)
    let bottomRight = CGPoint(x: inset + inner - pad,  y: inset + pad)

    // Triangle vertices — apex at center, base below
    let cx = s * 0.5
    let triApex      = CGPoint(x: cx,                      y: inset + inner * 0.5)
    let triBaseLeft  = CGPoint(x: inset + inner * 0.246,    y: inset + inner * 0.277)
    let triBaseRight = CGPoint(x: inset + inner * 0.754,    y: inset + inner * 0.277)

    // --- 1. Triangle (behind X) ---
    fgColor.setFill()
    let tri = NSBezierPath()
    tri.move(to: triApex)
    tri.line(to: triBaseLeft)
    tri.line(to: triBaseRight)
    tri.close()
    tri.fill()

    // --- 2. X lines (on top) ---
    let lineWidth = max(inner * 0.0586, 1.0)
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
