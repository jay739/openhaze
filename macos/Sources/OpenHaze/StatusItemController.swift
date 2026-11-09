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
    private var updateItem: NSMenuItem!
    private var updateSeparator: NSMenuItem!
    private var updatePage: URL?
    private var updateTimer: Timer?
    private var updateCheckRunning = false

    override init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        statusItem.button?.action = #selector(statusButtonClicked(_:))
        statusItem.button?.target = self
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        statusItem.button?.toolTip = "OpenHaze: click for controls, scroll to adjust intensity, ⌥-click to toggle"

        buildMenu()
        updateIcon()
        scheduleUpdateChecks()

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

        // Hidden until a check finds a newer release.
        updateItem = NSMenuItem(title: "", action: #selector(openUpdatePage), keyEquivalent: "")
        updateItem.target = self
        updateItem.isHidden = true
        menu.addItem(updateItem)
        updateSeparator = .separator()
        updateSeparator.isHidden = true
        menu.addItem(updateSeparator)

        toggleItem = NSMenuItem(title: "Dim Background Windows", action: #selector(toggleEnabled), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(.separator())
        menu.addItem(makeSliderItem())
        menu.addItem(.separator())

        let prefs = NSMenuItem(title: "Settings…", action: #selector(openPreferences), keyEquivalent: ",")
        prefs.target = self
        menu.addItem(prefs)

        let checkUpdates = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdatesNow), keyEquivalent: "")
        checkUpdates.target = self
        menu.addItem(checkUpdates)

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

    // MARK: - Updates

    /// Asks GitHub for a newer release shortly after launch, then daily.
    private func scheduleUpdateChecks() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            guard let self else { return }
            self.automaticUpdateCheck()
            self.updateTimer = Timer.scheduledTimer(withTimeInterval: 24 * 60 * 60, repeats: true) { [weak self] _ in
                self?.automaticUpdateCheck()
            }
        }
    }

    private func automaticUpdateCheck() {
        guard settings.checkForUpdates,
              !UpdateChecker.isDevelopmentBuild(UpdateChecker.currentVersion) else { return }
        checkForUpdates(userAsked: false)
    }

    @objc private func checkForUpdatesNow() {
        checkForUpdates(userAsked: true)
    }

    private func checkForUpdates(userAsked: Bool) {
        guard !updateCheckRunning else { return }
        updateCheckRunning = true
        let current = UpdateChecker.currentVersion
        UpdateChecker.fetchLatest { [weak self] result in
            guard let self else { return }
            self.updateCheckRunning = false
            switch result {
            case .failure(let error):
                // Automatic checks fail quietly; the next one runs tomorrow.
                if userAsked {
                    self.showAlert("Couldn't check for updates", error.localizedDescription)
                }
            case .success(let latest):
                let newer = UpdateChecker.isNewer(latest.tag, than: current)
                self.updateItem.isHidden = !newer
                self.updateSeparator.isHidden = !newer
                guard newer else {
                    if userAsked {
                        self.showAlert("You're up to date", "OpenHaze \(current) is the newest version.")
                    }
                    return
                }
                self.updatePage = latest.page
                self.updateItem.title = "Update Available: \(latest.tag)…"
                // Automatic checks announce each release once; the menu item stays until the user updates.
                if userAsked || self.settings.updateNotifiedTag != latest.tag {
                    self.settings.updateNotifiedTag = latest.tag
                    self.offerUpdate(latest, current: current)
                }
            }
        }
    }

    private func offerUpdate(_ latest: ReleaseInfo, current: String) {
        let alert = NSAlert()
        alert.messageText = "OpenHaze \(latest.tag) is available"
        alert.informativeText = "You have \(current). The release page has the new disk image."
        alert.addButton(withTitle: "Open Download Page")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(latest.page)
        }
    }

    @objc private func openUpdatePage() {
        NSWorkspace.shared.open(updatePage ?? UpdateChecker.releasesPage)
    }

    private func showAlert(_ title: String, _ message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
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
