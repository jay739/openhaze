import AppKit
import Combine

enum HighlightMode: Int, CaseIterable, Identifiable {
    case window = 0   // highlight the single front window
    case app = 1      // highlight all windows of the front app
    var id: Int { rawValue }
}

enum DesktopMode: Int, CaseIterable, Identifiable {
    case reveal = 0   // fade the haze out when the desktop gets focus
    case dimAll = 1   // dim every window when the desktop gets focus
    var id: Int { rawValue }
}

enum DisplayMode: Int, CaseIterable, Identifiable {
    case independent = 0  // highlight the top window on every display
    case single = 1       // only the display with the focused window stays lit
    var id: Int { rawValue }
}

final class Settings: ObservableObject {
    static let shared = Settings()
    private let d = UserDefaults.standard

    // MARK: stored properties

    @Published var enabled: Bool {
        didSet { d.set(enabled, forKey: "enabled") }
    }
    /// 0...1 — used for Light appearance, and for both when separateAppearance is off.
    @Published var intensity: Double {
        didSet { d.set(intensity, forKey: "intensity") }
    }
    @Published var intensityDark: Double {
        didSet { d.set(intensityDark, forKey: "intensityDark") }
    }
    @Published var separateAppearance: Bool {
        didSet { d.set(separateAppearance, forKey: "separateAppearance") }
    }
    @Published var hazeColorHex: String {
        didSet { d.set(hazeColorHex, forKey: "hazeColorHex") }
    }
    @Published var hazeColorDarkHex: String {
        didSet { d.set(hazeColorDarkHex, forKey: "hazeColorDarkHex") }
    }
    /// Seconds for the dim/undim fade. 0 = instant.
    @Published var animationDuration: Double {
        didSet { d.set(animationDuration, forKey: "animationDuration") }
    }
    @Published var highlightMode: HighlightMode {
        didSet { d.set(highlightMode.rawValue, forKey: "highlightMode") }
    }
    @Published var desktopMode: DesktopMode {
        didSet { d.set(desktopMode.rawValue, forKey: "desktopMode") }
    }
    @Published var displayMode: DisplayMode {
        didSet { d.set(displayMode.rawValue, forKey: "displayMode") }
    }
    @Published var fnReveal: Bool {
        didSet { d.set(fnReveal, forKey: "fnReveal") }
    }

    // MARK: derived

    var isDarkAppearance: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    var currentIntensity: Double {
        (separateAppearance && isDarkAppearance) ? intensityDark : intensity
    }

    var currentColor: NSColor {
        let hex = (separateAppearance && isDarkAppearance) ? hazeColorDarkHex : hazeColorHex
        return NSColor(hex: hex) ?? .black
    }

    func setCurrentIntensity(_ value: Double) {
        let v = min(1, max(0, value))
        if separateAppearance && isDarkAppearance {
            intensityDark = v
        } else {
            intensity = v
        }
    }

    // MARK: init

    private init() {
        d.register(defaults: [
            "enabled": true,
            "intensity": 0.35,
            "intensityDark": 0.45,
            "separateAppearance": false,
            "hazeColorHex": "000000",
            "hazeColorDarkHex": "000000",
            "animationDuration": 0.30,
            "highlightMode": HighlightMode.window.rawValue,
            "desktopMode": DesktopMode.reveal.rawValue,
            "displayMode": DisplayMode.independent.rawValue,
            "fnReveal": true,
        ])
        enabled = d.bool(forKey: "enabled")
        intensity = d.double(forKey: "intensity")
        intensityDark = d.double(forKey: "intensityDark")
        separateAppearance = d.bool(forKey: "separateAppearance")
        hazeColorHex = d.string(forKey: "hazeColorHex") ?? "000000"
        hazeColorDarkHex = d.string(forKey: "hazeColorDarkHex") ?? "000000"
        animationDuration = d.double(forKey: "animationDuration")
        highlightMode = HighlightMode(rawValue: d.integer(forKey: "highlightMode")) ?? .window
        desktopMode = DesktopMode(rawValue: d.integer(forKey: "desktopMode")) ?? .reveal
        displayMode = DisplayMode(rawValue: d.integer(forKey: "displayMode")) ?? .independent
        fnReveal = d.bool(forKey: "fnReveal")
    }
}

// MARK: - NSColor hex helpers

extension NSColor {
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt32(s, radix: 16) else { return nil }
        self.init(srgbRed: CGFloat((v >> 16) & 0xFF) / 255,
                  green: CGFloat((v >> 8) & 0xFF) / 255,
                  blue: CGFloat(v & 0xFF) / 255,
                  alpha: 1)
    }

    var hexString: String {
        let c = usingColorSpace(.sRGB) ?? .black
        let r = Int(round(c.redComponent * 255))
        let g = Int(round(c.greenComponent * 255))
        let b = Int(round(c.blueComponent * 255))
        return String(format: "%02X%02X%02X", r, g, b)
    }
}
