// Generates the disk image window background in the icon's palette: haze that
// clears from left to right, a warm glow behind Applications, and an arrow whose
// haze particles condense into a solid stroke on the way there.
// Usage: makedmgbackground /path/to/background.png
//        (also writes background@2x.png beside it; dmgbuild pairs the two)
import AppKit

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "dmg-background.png"

// Points, top-left origin like Finder. dmg-settings.py uses the same window size
// and icon centers; the arrow and the glow are placed relative to the centers.
let size = CGSize(width: 640, height: 360)
let appCenter = CGPoint(x: 160, y: 160)
let applicationsCenter = CGPoint(x: 480, y: 160)

// ink, cream and amber are the plate navy, the focused window and the glow from
// makeicon.swift; haze is a light grey-lavender for the dimmed side.
let ink = NSColor(srgbRed: 0.16, green: 0.18, blue: 0.26, alpha: 1)
let haze = NSColor(srgbRed: 0.89, green: 0.89, blue: 0.92, alpha: 1)
let cream = NSColor(srgbRed: 0.99, green: 0.96, blue: 0.90, alpha: 1)
let amber = NSColor(srgbRed: 1.0, green: 0.78, blue: 0.35, alpha: 1)

// The arrow is one cubic curve that arcs up between the two 128 pt icons,
// starting and ending 22 pt clear of them.
let start = CGPoint(x: appCenter.x + 86, y: appCenter.y + 10)
let control1 = CGPoint(x: appCenter.x + 128, y: appCenter.y - 36)
let control2 = CGPoint(x: applicationsCenter.x - 128, y: applicationsCenter.y - 36)
let end = CGPoint(x: applicationsCenter.x - 86, y: applicationsCenter.y + 2)

func point(at t: CGFloat) -> CGPoint {
    let u = 1 - t
    let a = u * u * u, b = 3 * u * u * t, c = 3 * u * t * t, d = t * t * t
    return CGPoint(x: a * start.x + b * control1.x + c * control2.x + d * end.x,
                   y: a * start.y + b * control1.y + c * control2.y + d * end.y)
}

func tangent(at t: CGFloat) -> CGVector {
    let u = 1 - t
    let dx = 3 * u * u * (control1.x - start.x) + 6 * u * t * (control2.x - control1.x)
        + 3 * t * t * (end.x - control2.x)
    let dy = 3 * u * u * (control1.y - start.y) + 6 * u * t * (control2.y - control1.y)
        + 3 * t * t * (end.y - control2.y)
    let length = max(hypot(dx, dy), 0.001)
    return CGVector(dx: dx / length, dy: dy / length)
}

func mix(_ a: NSColor, _ b: NSColor, _ t: CGFloat) -> NSColor {
    a.blended(withFraction: min(max(t, 0), 1), of: b) ?? b
}

func draw() {
    // Haze on the left clearing to the focused window's cream on the right.
    NSGradient(colorsAndLocations: (haze, 0.0), (haze, 0.12), (cream, 0.68), (cream, 1.0))?
        .draw(in: NSRect(origin: .zero, size: size), angle: 0)

    // Warm glow behind Applications, like the one behind the icon's front window.
    NSGradient(colors: [amber.withAlphaComponent(0.3), amber.withAlphaComponent(0)])?
        .draw(fromCenter: applicationsCenter, radius: 0, toCenter: applicationsCenter,
              radius: 118, options: [])

    // Haze particles come into focus along the first half of the curve: soft,
    // faint and scattered at the start, then crisp, dark and lined up.
    let particles = 16
    for i in 0..<particles {
        let progress = CGFloat(i) / CGFloat(particles - 1)
        let t = 0.5 * pow(progress, 0.8)
        let p = point(at: t)
        let along = tangent(at: t)
        let scatter = sin(CGFloat(i) * 2.4) * 6 * pow(1 - progress, 1.5)
        let center = CGPoint(x: p.x - along.dy * scatter, y: p.y + along.dx * scatter)
        let color = mix(haze, ink, 0.3 + 0.7 * progress).withAlphaComponent(0.25 + 0.7 * progress)
        let outer = 5.4 - 4.4 * progress
        let sharpness = 0.1 + 0.8 * progress
        NSGradient(colorsAndLocations: (color, 0), (color, sharpness), (color.withAlphaComponent(0), 1))?
            .draw(fromCenter: center, radius: 0, toCenter: center, radius: outer, options: [])
    }

    // The condensed stroke thickens toward the chevron.
    ink.set()
    let segments = 40
    for step in 0..<segments {
        let a = 0.5 + 0.5 * CGFloat(step) / CGFloat(segments)
        let b = 0.5 + 0.5 * CGFloat(step + 1) / CGFloat(segments)
        let segment = NSBezierPath()
        segment.move(to: point(at: a))
        segment.line(to: point(at: b))
        segment.lineWidth = 1.6 + 1.2 * CGFloat(step) / CGFloat(segments)
        segment.lineCapStyle = .round
        segment.stroke()
    }
    let chevron = NSBezierPath()
    let back = tangent(at: 1)
    let arm: CGFloat = 11, spread: CGFloat = 0.72
    for sign in [CGFloat(1), -1] {
        let angle = atan2(back.dy, back.dx) + .pi + sign * spread
        chevron.move(to: CGPoint(x: end.x + cos(angle) * arm, y: end.y + sin(angle) * arm))
        chevron.line(to: end)
    }
    chevron.lineWidth = 2.8
    chevron.lineCapStyle = .round
    chevron.lineJoinStyle = .round
    chevron.stroke()

    // Plain instructions for anyone who has not installed a Mac app this way.
    let plain = NSFont.systemFont(ofSize: 13, weight: .medium)
    let rounded = plain.fontDescriptor.withDesign(.rounded).flatMap { NSFont(descriptor: $0, size: 13) }
    let caption = NSAttributedString(string: "Drag OpenHaze to Applications", attributes: [
        .font: rounded ?? plain,
        .foregroundColor: ink.withAlphaComponent(0.6),
    ])
    let captionSize = caption.size()
    caption.draw(at: CGPoint(x: (size.width - captionSize.width) / 2, y: 300 - captionSize.height / 2))
}

func pngData(scale: CGFloat) -> Data? {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil,
                                     pixelsWide: Int(size.width * scale),
                                     pixelsHigh: Int(size.height * scale),
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0),
          let bitmap = NSGraphicsContext(bitmapImageRep: rep) else { return nil }
    let cg = bitmap.cgContext
    cg.scaleBy(x: scale, y: scale)
    cg.translateBy(x: 0, y: size.height)
    cg.scaleBy(x: 1, y: -1)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(cgContext: cg, flipped: true)
    draw()
    NSGraphicsContext.restoreGraphicsState()
    rep.size = size  // records 144 dpi on the @2x image
    return rep.representation(using: .png, properties: [:])
}

let output = URL(fileURLWithPath: outputPath)
let retina = output.deletingPathExtension().path + "@2x.png"
for (scale, path) in [(CGFloat(1), output.path), (2, retina)] {
    guard let data = pngData(scale: scale) else { fatalError("render \(path)") }
    try data.write(to: URL(fileURLWithPath: path))
    print("Wrote \(path)")
}
