import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings = Settings.shared
    private(set) var engine: HazeEngine!
    private var statusItemController: StatusItemController!

    func applicationDidFinishLaunching(_ notification: Notification) {
        engine = HazeEngine(settings: settings)
        statusItemController = StatusItemController()
        HotkeyManager.shared.start()

        OnboardingWindowController.shared.onGranted = { [weak self] in
            self?.engine.accessibilityGranted()
        }

        engine.start()

        if !AXIsProcessTrusted() {
            OnboardingWindowController.shared.show()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: - URL scheme (openhaze://…)

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls { handle(url) }
        // Opening an openhaze:// URL activates us; hand focus straight back so
        // the caller's window keeps keyboard focus (unless one of ours is open).
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            if NSApp.windows.allSatisfy({ !$0.isVisible || $0 is OverlayWindow }) {
                NSApp.deactivate()
            }
        }
    }

    private func handle(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return }
        let command = (components.host ?? components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))).lowercased()

        switch command {
        case "on":
            settings.enabled = true
        case "off":
            settings.enabled = false
        case "toggle":
            settings.enabled.toggle()
        case "intensity":
            let raw = components.queryItems?.first(where: { $0.name == "value" })?.value
                ?? components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            if let v = Double(raw) {
                settings.setCurrentIntensity(v > 1 ? v / 100 : v)
            }
        default:
            break
        }
    }

    // MARK: - AppleScript (tell application "OpenHaze" …)

    @objc func application(_ sender: NSApplication, delegateHandlesKey key: String) -> Bool {
        key == "enabled" || key == "intensity"
    }

    @objc var enabled: Bool {
        get { settings.enabled }
        set { settings.enabled = newValue }
    }

    @objc var intensity: Int {
        get { Int(round(settings.currentIntensity * 100)) }
        set { settings.setCurrentIntensity(Double(newValue) / 100) }
    }
}
