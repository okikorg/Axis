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
    let path = NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius)
    bgColor.setFill()
    path.fill()

    // Draw "A" - use Roboto Mono if available, otherwise SF Mono or system monospaced
    let fontSize = s * 0.58
    let font: NSFont = {
        if let roboto = NSFont(name: "RobotoMono-Bold", size: fontSize) {
            return roboto
        }
        if let sfMono = NSFont(name: "SFMono-Bold", size: fontSize) {
            return sfMono
        }
        return NSFont.monospacedSystemFont(ofSize: fontSize, weight: .bold)
    }()

    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: fgColor,
    ]

    let str = "A" as NSString
    let strSize = str.size(withAttributes: attrs)

    // Center the glyph precisely - nudge up slightly for optical centering
    let x = (s - strSize.width) / 2
    let y = (s - strSize.height) / 2 + s * 0.02
    let drawPoint = NSPoint(x: x, y: y)

    str.draw(at: drawPoint, withAttributes: attrs)

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
