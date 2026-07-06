import AppKit
import ApplicationServices

/// Private-but-stable SPI that maps an AXUIElement window to its CGWindowID.
/// Used by most window-management utilities (AltTab, Rectangle, yabai, …).
@_silgen_name("_AXUIElementGetWindow")
func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: UnsafeMutablePointer<CGWindowID>) -> AXError

/// Watches for anything that could change which window should be highlighted:
/// app activation, focused-window changes (via Accessibility), Space switches,
/// hide/unhide, and the Fn key (temporary reveal).
///
/// Works in two tiers:
///  - With Accessibility access: instant, event-driven via AXObserver.
///  - Without: the engine's poll timer picks up changes from the window list.
final class FocusTracker {
    var onChange: (() -> Void)?
    var onFnChanged: ((Bool) -> Void)?
    private(set) var fnHeld = false

    private var observer: AXObserver?
    private var observedPID: pid_t = -1
    private var appElement: AXUIElement?
    private var eventMonitors: [Any] = []

    private let axNotifications: [CFString] = [
        kAXFocusedWindowChangedNotification as CFString,
        kAXMainWindowChangedNotification as CFString,
        kAXWindowCreatedNotification as CFString,
        kAXWindowMiniaturizedNotification as CFString,
        kAXWindowDeminiaturizedNotification as CFString,
        kAXApplicationHiddenNotification as CFString,
        kAXApplicationShownNotification as CFString,
    ]

    func start() {
        let nc = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.didActivateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification,
            NSWorkspace.activeSpaceDidChangeNotification,
        ]
        for name in names {
            nc.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.frontMayHaveChanged()
            }
        }
        nc.addObserver(forName: NSWorkspace.didTerminateApplicationNotification,
                       object: nil, queue: .main) { [weak self] note in
            guard let self else { return }
            if let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
               app.processIdentifier == self.observedPID {
                self.detachObserver()
            }
            self.onChange?()
        }

        // Fn key: temporary reveal while held. Global monitors need Accessibility access;
        // if it isn't granted the monitor simply never fires.
        let handler: (NSEvent) -> Void = { [weak self] event in
            guard let self else { return }
            let held = event.modifierFlags.contains(.function)
            if held != self.fnHeld {
                self.fnHeld = held
                self.onFnChanged?(held)
            }
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged, handler: handler) {
            eventMonitors.append(global)
        }
        eventMonitors.append(NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
            handler(event)
            return event
        } as Any)

        frontMayHaveChanged()
    }

    /// Re-attach AX observation (called after Accessibility access is granted).
    func refreshTrust() {
        observedPID = -1
        detachObserver()
        frontMayHaveChanged()
    }

    private func frontMayHaveChanged() {
        let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1
        attachObserver(to: pid)
        onChange?()
    }

    // MARK: - AX observation

    private func attachObserver(to pid: pid_t) {
        guard pid != observedPID else { return }
        detachObserver()
        observedPID = pid
        guard pid > 0, AXIsProcessTrusted() else { return }

        var obs: AXObserver?
        guard AXObserverCreate(pid, focusTrackerAXCallback, &obs) == .success, let obs else { return }
        observer = obs
        let element = AXUIElementCreateApplication(pid)
        appElement = element
        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        for note in axNotifications {
            AXObserverAddNotification(obs, element, note, refcon)
        }
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
    }

    private func detachObserver() {
        if let obs = observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(obs), .defaultMode)
        }
        observer = nil
        appElement = nil
    }

    /// CGWindowID of the focused window of the front app, if Accessibility can tell us.
    func focusedWindowID() -> CGWindowID? {
        guard AXIsProcessTrusted() else { return nil }
        let pid = NSWorkspace.shared.frontmostApplication?.processIdentifier ?? -1
        guard pid > 0 else { return nil }
        let appEl = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appEl, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let value, CFGetTypeID(value) == AXUIElementGetTypeID()
        else { return nil }
        let windowEl = unsafeDowncast(value as AnyObject, to: AXUIElement.self)
        var windowID: CGWindowID = 0
        guard _AXUIElementGetWindow(windowEl, &windowID) == .success, windowID != 0 else { return nil }
        return windowID
    }
}

private func focusTrackerAXCallback(observer: AXObserver,
                                    element: AXUIElement,
                                    notification: CFString,
                                    refcon: UnsafeMutableRawPointer?) {
    guard let refcon else { return }
    let tracker = Unmanaged<FocusTracker>.fromOpaque(refcon).takeUnretainedValue()
    DispatchQueue.main.async {
        tracker.onChange?()
    }
}
