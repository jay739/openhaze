import AppKit

/// Keep fullscreen detection independent of the window's compositing layer.
/// Native fullscreen windows can remain at the ordinary layer (0).
enum FullscreenDetection {
    static func screenIDs(windows: [WindowInfo], frontPID: pid_t?,
                          focusedWindowID: CGWindowID?, focusedWindowIsFullscreen: Bool,
                          screens: [CGDirectDisplayID: CGRect],
                          excluding excluded: Set<CGWindowID>) -> Set<CGDirectDisplayID> {
        guard let pid = frontPID else { return [] }
        // Preserve the window-list fallback when Accessibility is unavailable.
        var result = Set(screens.compactMap { id, frame in
            let covering = windows.contains {
                $0.pid == pid && $0.layer != 0 && !excluded.contains($0.id) &&
                area($0.bounds.intersection(frame)) >= area(frame) * 0.9
            }
            return covering ? id : nil
        })
        if focusedWindowIsFullscreen {
            // Prefer the exact AX window. Its CG layer can still be zero.
            let focused = windows.first {
                $0.id == focusedWindowID && $0.pid == pid && !excluded.contains($0.id)
            } ?? windows.first {
                $0.pid == pid && $0.layer == 0 && $0.alpha > 0.01 && !excluded.contains($0.id)
            }
            if let focused,
               let screen = screens.max(by: {
                   area(focused.bounds.intersection($0.value)) < area(focused.bounds.intersection($1.value))
               }), area(focused.bounds.intersection(screen.value)) > 0 {
                result.insert(screen.key)
            } else if screens.count == 1, let id = screens.keys.first {
                // CGWindowList may briefly omit the window during a Space transition.
                result.insert(id)
            }
        }
        return result
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        max(0, rect.width) * max(0, rect.height)
    }
}
