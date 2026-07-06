// Generates AppIcon.icns: a bright, glowing front window over dimmed background
// windows on a dark squircle — the whole app in one picture.
// Usage: swift makeicon.swift /path/to/AppIcon.icns
import AppKit

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "AppIcon.icns"

func drawIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    defer { image.unlockFocus() }

    let s = size / 1024.0

    // macOS-style squircle plate with ~10% margin
    let plate = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let platePath = NSBezierPath(roundedRect: plate, xRadius: 185 * s, yRadius: 185 * s)
    NSGradient(colors: [
        NSColor(srgbRed: 0.16, green: 0.18, blue: 0.26, alpha: 1),
        NSColor(srgbRed: 0.05, green: 0.06, blue: 0.10, alpha: 1),
    ])?.draw(in: platePath, angle: -90)

    NSGraphicsContext.current?.saveGraphicsState()
    platePath.addClip()

    func window(_ rect: NSRect, radius: CGFloat, body: NSColor, bar: NSColor, dim: CGFloat) {
        let path = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        body.set()
        path.fill()
        // title bar
        let barRect = NSRect(x: rect.minX, y: rect.maxY - 46 * s, width: rect.width, height: 46 * s)
        let barPath = NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        barPath.addClip()
        bar.set()
        barRect.fill()
        if dim > 0 {
            NSColor(srgbRed: 0.03, green: 0.04, blue: 0.07, alpha: dim).set()
            path.fill()
        }
    }

    // Two dimmed background windows
    NSGraphicsContext.current?.saveGraphicsState()
    window(NSRect(x: 158 * s, y: 420 * s, width: 380 * s, height: 300 * s), radius: 26 * s,
           body: NSColor(white: 0.82, alpha: 1), bar: NSColor(white: 0.70, alpha: 1), dim: 0.62)
    NSGraphicsContext.current?.restoreGraphicsState()
    NSGraphicsContext.current?.saveGraphicsState()
    window(NSRect(x: 500 * s, y: 470 * s, width: 360 * s, height: 260 * s), radius: 26 * s,
           body: NSColor(white: 0.82, alpha: 1), bar: NSColor(white: 0.70, alpha: 1), dim: 0.62)
    NSGraphicsContext.current?.restoreGraphicsState()

    // Warm glow behind the front window
    let glowCenter = NSPoint(x: 512 * s, y: 380 * s)
    NSGradient(colors: [
        NSColor(srgbRed: 1.0, green: 0.78, blue: 0.35, alpha: 0.55),
        NSColor(srgbRed: 1.0, green: 0.78, blue: 0.35, alpha: 0.0),
    ])?.draw(fromCenter: glowCenter, radius: 60 * s,
             toCenter: glowCenter, radius: 430 * s, options: [])

    // Front (focused) window — bright and warm
    NSGraphicsContext.current?.saveGraphicsState()
    let front = NSRect(x: 232 * s, y: 190 * s, width: 560 * s, height: 380 * s)
    let shadow = NSShadow()
    shadow.shadowColor = NSColor.black.withAlphaComponent(0.55)
    shadow.shadowBlurRadius = 34 * s
    shadow.shadowOffset = NSSize(width: 0, height: -14 * s)
    shadow.set()
    NSColor(srgbRed: 0.99, green: 0.96, blue: 0.90, alpha: 1).set()
    NSBezierPath(roundedRect: front, xRadius: 34 * s, yRadius: 34 * s).fill()
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGraphicsContext.current?.saveGraphicsState()
    NSBezierPath(roundedRect: front, xRadius: 34 * s, yRadius: 34 * s).addClip()
    // title bar
    NSColor(srgbRed: 1.0, green: 0.80, blue: 0.42, alpha: 1).set()
    NSRect(x: front.minX, y: front.maxY - 64 * s, width: front.width, height: 64 * s).fill()
    // traffic lights
    let lights: [NSColor] = [
        NSColor(srgbRed: 1.0, green: 0.37, blue: 0.34, alpha: 1),
        NSColor(srgbRed: 1.0, green: 0.74, blue: 0.18, alpha: 1),
        NSColor(srgbRed: 0.20, green: 0.78, blue: 0.35, alpha: 1),
    ]
    for (i, color) in lights.enumerated() {
        color.set()
        let x = front.minX + (34 + CGFloat(i) * 40) * s
        let y = front.maxY - 44 * s
        NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 24 * s, height: 24 * s)).fill()
    }
    // content lines
    NSColor(srgbRed: 0.93, green: 0.83, blue: 0.64, alpha: 1).set()
    for row in 0..<3 {
        let width: CGFloat = row == 2 ? 260 : 420
        NSBezierPath(roundedRect: NSRect(x: front.minX + 44 * s,
                                         y: front.maxY - (140 + CGFloat(row) * 74) * s,
                                         width: width * s, height: 34 * s),
                     xRadius: 17 * s, yRadius: 17 * s).fill()
    }
    NSGraphicsContext.current?.restoreGraphicsState()

    NSGraphicsContext.current?.restoreGraphicsState()  // plate clip
    return image
}

func pngData(_ image: NSImage, pixels: Int) -> Data? {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    NSGraphicsContext.current?.imageInterpolation = .high
    image.draw(in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
               from: .zero, operation: .copy, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

let master = drawIcon(size: 1024)
let iconsetURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: iconsetURL)
try FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let entries: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in entries {
    guard let data = pngData(master, pixels: px) else { fatalError("render \(name)") }
    try data.write(to: iconsetURL.appendingPathComponent("\(name).png"))
}

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconsetURL.path, "-o", outputPath]
try task.run()
task.waitUntilExit()
guard task.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Wrote \(outputPath)")
