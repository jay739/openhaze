import AppKit

/// One on-screen window as reported by the window server (no permissions needed).
struct WindowInfo {
    let id: CGWindowID
    let pid: pid_t
    let layer: Int
    let bounds: CGRect   // global coordinates, origin at top-left of the primary display
    let alpha: Double
}

/// A front-to-back snapshot of every on-screen window.
struct WindowSnapshot {
    let windows: [WindowInfo]

    init() {
        let raw = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements],
                                              kCGNullWindowID) as? [[String: Any]]) ?? []
        windows = raw.compactMap { item in
            guard let id = item[kCGWindowNumber as String] as? CGWindowID ?? (item[kCGWindowNumber as String] as? Int).map(CGWindowID.init),
                  let pid = (item[kCGWindowOwnerPID as String] as? Int).map(pid_t.init),
                  let layer = item[kCGWindowLayer as String] as? Int,
                  let boundsDict = item[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary)
            else { return nil }
            let alpha = item[kCGWindowAlpha as String] as? Double ?? 1
            return WindowInfo(id: id, pid: pid, layer: layer, bounds: bounds, alpha: alpha)
        }
    }

    func index(of id: CGWindowID) -> Int? {
        windows.firstIndex { $0.id == id }
    }

    func contains(_ id: CGWindowID) -> Bool {
        index(of: id) != nil
    }

    /// Normal-level windows that could be highlighted/dimmed, front-to-back.
    /// Skips invisible windows and tiny helper windows.
    func normalWindows(excluding excluded: Set<CGWindowID>) -> [WindowInfo] {
        windows.filter {
            $0.layer == 0 && !excluded.contains($0.id) && $0.alpha > 0.01 &&
            $0.bounds.width >= 40 && $0.bounds.height >= 40
        }
    }
}

extension NSScreen {
    /// This screen's frame in CGWindowList coordinates (origin top-left of primary display).
    var cgFrame: CGRect {
        guard let primary = NSScreen.screens.first else { return frame }
        return CGRect(x: frame.minX,
                      y: primary.frame.maxY - frame.maxY,
                      width: frame.width,
                      height: frame.height)
    }

    var displayID: CGDirectDisplayID {
        (deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? 0
    }
}

extension WindowInfo {
    /// True if the window's center lies on the given screen (CG coordinates).
    func isOn(cgScreenFrame: CGRect) -> Bool {
        cgScreenFrame.contains(CGPoint(x: bounds.midX, y: bounds.midY))
    }
}
