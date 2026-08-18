// Generates docs/logo.png (1024×1024) — the KeepAwake icon, drawn from
// SF Symbols: a steaming cup under a crescent moon on a night-sky gradient.
// Run: swift make-icon.swift
import AppKit

let size = 1024
let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
                           bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                           isPlanar: false, colorSpaceName: .deviceRGB,
                           bytesPerRow: 0, bitsPerPixel: 0)!
let ctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = ctx

func symbol(_ name: String, pointSize: CGFloat, color: NSColor) -> NSImage {
    let base = NSImage(systemSymbolName: name, accessibilityDescription: nil)!
        .withSymbolConfiguration(.init(pointSize: pointSize, weight: .medium))!
    let img = NSImage(size: base.size)
    img.lockFocus()
    base.draw(at: .zero, from: .zero, operation: .sourceOver, fraction: 1.0)
    color.set()
    NSRect(origin: .zero, size: base.size).fill(using: .sourceAtop)
    img.unlockFocus()
    return img
}

// Rounded-square night gradient (macOS icon proportions: ~10% margin)
let square = NSRect(x: 64, y: 64, width: 896, height: 896)
let path = NSBezierPath(roundedRect: square, xRadius: 200, yRadius: 200)
NSGradient(starting: NSColor(calibratedRed: 0.16, green: 0.12, blue: 0.45, alpha: 1),
           ending: NSColor(calibratedRed: 0.05, green: 0.07, blue: 0.20, alpha: 1))!
    .draw(in: path, angle: -90)

path.addClip()

// Crescent moon, top-right
let moon = symbol("moon.fill", pointSize: 170,
                  color: NSColor(calibratedRed: 0.97, green: 0.91, blue: 0.72, alpha: 0.95))
moon.draw(in: NSRect(x: 640, y: 640, width: moon.size.width, height: moon.size.height))

// Tiny stars
for (x, y, s) in [(270.0, 740.0, 44.0), (420.0, 640.0, 26.0), (700.0, 480.0, 30.0)] {
    let star = symbol("sparkle", pointSize: s,
                      color: NSColor(calibratedWhite: 1.0, alpha: 0.85))
    star.draw(in: NSRect(x: x, y: y, width: star.size.width, height: star.size.height))
}

// The cup, front and center
let cup = symbol("cup.and.heat.waves.fill", pointSize: 430, color: .white)
cup.draw(in: NSRect(x: (CGFloat(size) - cup.size.width) / 2, y: 150,
                    width: cup.size.width, height: cup.size.height))

NSGraphicsContext.restoreGraphicsState()
let png = rep.representation(using: .png, properties: [:])!
let out = URL(fileURLWithPath: "docs/logo.png")
try FileManager.default.createDirectory(atPath: "docs", withIntermediateDirectories: true)
try png.write(to: out)
print("wrote \(out.path)")
