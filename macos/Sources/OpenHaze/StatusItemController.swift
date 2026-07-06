import AppKit
import Combine

/// The menu bar presence: icon, dropdown with a live intensity slider,
/// scroll-over-the-icon intensity adjustment, and option-click to toggle.
final class StatusItemController: NSObject, NSMenuDelegate {
    private let settings = Settings.shared
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    private var toggleItem: NSMenuItem!
    private var slider: NSSlider!
    private var valueLabel: NSTextField!
    private var scrollMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        statusItem.button?.action = #selector(statusButtonClicked(_:))
        statusItem.button?.target = self
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.toolTip = "OpenHaze — click for controls, scroll to adjust intensity, ⌥-click to toggle"

        buildMenu()
        updateIcon()

        // Scrolling over the menu bar icon adjusts intensity (like HazeOver).
        scrollMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, let button = self.statusItem.button,
                  event.window === button.window else { return event }
            let direction: Double = event.isDirectionInvertedFromDevice ? -1 : 1
            let delta = event.scrollingDeltaY * direction
            self.settings.setCurrentIntensity(self.settings.currentIntensity + delta * 0.01)
            return nil
        }

        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                DispatchQueue.main.async { self?.updateIcon() }
            }
            .store(in: &cancellables)
    }

    // MARK: - Menu

    private func buildMenu() {
        menu.delegate = self

        toggleItem = NSMenuItem(title: "Dim Background Windows", action: #selector(toggleEnabled), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())
        menu.addItem(makeSliderItem())
        menu.addItem(.separator())

        let prefs = NSMenuItem(title: "Settings…", action: #selector(openPreferences), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        let about = NSMenuItem(title: "About OpenHaze", action: #selector(openAbout), keyEquivalent: "")
        about.target = self
        menu.addItem(about)

        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit OpenHaze", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)
    }

    private func makeSliderItem() -> NSMenuItem {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: 260, height: 52))

        let title = NSTextField(labelWithString: "Intensity")
        title.font = .systemFont(ofSize: 12, weight: .medium)
        title.textColor = .secondaryLabelColor
        title.frame = NSRect(x: 14, y: 32, width: 120, height: 16)
        container.addSubview(title)

        valueLabel = NSTextField(labelWithString: "35%")
        valueLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        valueLabel.textColor = .secondaryLabelColor
        valueLabel.alignment = .right
        valueLabel.frame = NSRect(x: 186, y: 32, width: 60, height: 16)
        container.addSubview(valueLabel)

        slider = NSSlider(value: settings.currentIntensity, minValue: 0, maxValue: 1,
                          target: self, action: #selector(sliderChanged(_:)))
        slider.isContinuous = true
        slider.frame = NSRect(x: 12, y: 6, width: 236, height: 24)
        container.addSubview(slider)

        let item = NSMenuItem()
        item.view = container
        return item
    }

    func menuWillOpen(_ menu: NSMenu) {
        toggleItem.state = settings.enabled ? .on : .off
        syncSlider()
    }

    private func syncSlider() {
        slider.doubleValue = settings.currentIntensity
        valueLabel.stringValue = "\(Int(round(settings.currentIntensity * 100)))%"
    }

    // MARK: - Actions

    @objc private func statusButtonClicked(_ sender: Any?) {
        let event = NSApp.currentEvent
        let optionHeld = event?.modifierFlags.contains(.option) == true
        let rightClick = event?.type == .rightMouseUp
        if optionHeld || rightClick {
            toggleEnabled()
        } else {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        }
    }

    @objc private func toggleEnabled() {
        settings.enabled.toggle()
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        settings.setCurrentIntensity(sender.doubleValue)
        valueLabel.stringValue = "\(Int(round(settings.currentIntensity * 100)))%"
    }

    @objc private func openPreferences() {
        PreferencesWindowController.shared.show()
    }

    @objc private func openAbout() {
        PreferencesWindowController.shared.show(tab: .about)
    }

    // MARK: - Icon

    private func updateIcon() {
        let name = settings.enabled ? "rectangle.inset.filled.on.rectangle" : "rectangle.on.rectangle"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "OpenHaze")
        image?.isTemplate = true
        statusItem.button?.image = image
        statusItem.button?.appearsDisabled = !settings.enabled
    }
}
