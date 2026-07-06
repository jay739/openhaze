import AppKit
import SwiftUI
import ServiceManagement

enum PrefsTab: Hashable {
    case general, focus, displays, shortcuts, automation, about
}

final class PrefsTabState: ObservableObject {
    @Published var tab: PrefsTab = .general
}

final class PreferencesWindowController {
    static let shared = PreferencesWindowController()
    private var window: NSWindow?
    private let tabState = PrefsTabState()

    func show(tab: PrefsTab = .general) {
        tabState.tab = tab
        if window == nil {
            let host = NSHostingController(rootView: PrefsRootView(tabState: tabState))
            let w = NSWindow(contentViewController: host)
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.title = "OpenHaze Settings"
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct PrefsRootView: View {
    @ObservedObject var tabState: PrefsTabState

    var body: some View {
        TabView(selection: $tabState.tab) {
            GeneralTab()
                .tabItem { Label("General", systemImage: "slider.horizontal.3") }
                .tag(PrefsTab.general)
            FocusTab()
                .tabItem { Label("Focus", systemImage: "macwindow") }
                .tag(PrefsTab.focus)
            DisplaysTab()
                .tabItem { Label("Displays", systemImage: "display.2") }
                .tag(PrefsTab.displays)
            ShortcutsTab()
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
                .tag(PrefsTab.shortcuts)
            AutomationTab()
                .tabItem { Label("Automation", systemImage: "gearshape.2") }
                .tag(PrefsTab.automation)
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(PrefsTab.about)
        }
        .frame(width: 580, height: 500)
    }
}

// MARK: - General

struct GeneralTab: View {
    @ObservedObject var settings = Settings.shared
    @StateObject private var axBox = StateBox(AXIsProcessTrusted())
    private var accessibilityGranted: Bool { axBox.value }
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                Toggle("Dim background windows", isOn: $settings.enabled)
            } footer: {
                Text("The front window stays bright while everything behind it fades into the haze.")
            }

            Section {
                if settings.separateAppearance {
                    IntensityRow(title: "Light appearance", value: $settings.intensity)
                    IntensityRow(title: "Dark appearance", value: $settings.intensityDark)
                } else {
                    IntensityRow(title: "Intensity", value: $settings.intensity)
                }
                Toggle("Separate settings for Light and Dark appearance", isOn: $settings.separateAppearance)
            } header: {
                Text("Intensity")
            } footer: {
                Text("Tip: scroll over the menu bar icon to adjust intensity anytime.")
            }

            Section("Haze color") {
                ColorPickerRow(title: settings.separateAppearance ? "Light appearance" : "Color",
                               hex: $settings.hazeColorHex)
                if settings.separateAppearance {
                    ColorPickerRow(title: "Dark appearance", hex: $settings.hazeColorDarkHex)
                }
                Button("Reset to Black") {
                    settings.hazeColorHex = "000000"
                    settings.hazeColorDarkHex = "000000"
                }
            }

            Section {
                LabeledContent("Fade duration") {
                    Slider(value: $settings.animationDuration, in: 0...1.5)
                    Text(String(format: "%.2f s", settings.animationDuration))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .trailing)
                }
            } header: {
                Text("Animation")
            } footer: {
                Text("How quickly the haze follows focus changes. 0 is instant.")
            }

            Section {
                LaunchAtLoginRow()
                LabeledContent("Accessibility access") {
                    HStack(spacing: 6) {
                        Image(systemName: accessibilityGranted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundStyle(accessibilityGranted ? .green : .orange)
                        Text(accessibilityGranted ? "Granted" : "Not granted")
                            .foregroundStyle(.secondary)
                        if !accessibilityGranted {
                            Button("Grant…") { OnboardingWindowController.shared.show() }
                        }
                    }
                }
            } footer: {
                Text("Without Accessibility access, focus changes are detected by polling — it still works, just a touch less instantly, and the Fn-reveal gesture is unavailable.")
            }
        }
        .formStyle(.grouped)
        .onReceive(timer) { _ in
            let trusted = AXIsProcessTrusted()
            if trusted != axBox.value { axBox.value = trusted }
        }
    }
}

struct IntensityRow: View {
    let title: String
    @Binding var value: Double

    var body: some View {
        LabeledContent(title) {
            Slider(value: $value, in: 0...1)
            Text("\(Int(round(value * 100)))%")
                .monospacedDigit()
                .foregroundStyle(.secondary)
                .frame(width: 44, alignment: .trailing)
        }
    }
}

struct ColorPickerRow: View {
    let title: String
    @Binding var hex: String

    var body: some View {
        ColorPicker(title, selection: Binding<Color>(
            get: { Color(nsColor: NSColor(hex: hex) ?? .black) },
            set: { hex = NSColor($0).hexString }
        ), supportsOpacity: false)
    }
}

struct LaunchAtLoginRow: View {
    @StateObject private var enabledBox = StateBox(SMAppService.mainApp.status == .enabled)
    @StateObject private var errorBox = StateBox<String?>(nil)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Toggle("Start OpenHaze at login", isOn: Binding(
                get: { enabledBox.value },
                set: { newValue in
                    do {
                        if newValue {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                        enabledBox.value = newValue
                        errorBox.value = nil
                    } catch {
                        errorBox.value = error.localizedDescription
                        enabledBox.value = SMAppService.mainApp.status == .enabled
                    }
                }
            ))
            if let error = errorBox.value {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        }
    }
}

// MARK: - Focus

struct FocusTab: View {
    @ObservedObject var settings = Settings.shared

    var body: some View {
        Form {
            Section {
                Picker("Highlight", selection: $settings.highlightMode) {
                    Text("The active window").tag(HighlightMode.window)
                    Text("All windows of the active app").tag(HighlightMode.app)
                }
                .pickerStyle(.radioGroup)
            } footer: {
                Text("“Active window” focuses on exactly one thing at a time. “Active app” keeps every window of the front application bright — handy for palettes and inspectors.")
            }

            Section {
                Picker("When the desktop gets focus", selection: $settings.desktopMode) {
                    Text("Reveal — fade the haze out").tag(DesktopMode.reveal)
                    Text("Dim all windows").tag(DesktopMode.dimAll)
                }
                .pickerStyle(.radioGroup)
            } footer: {
                Text("Click the wallpaper to try it.")
            }

            Section {
                Toggle("Hold Fn to temporarily reveal all windows", isOn: $settings.fnReveal)
            } footer: {
                Text("Great while dragging things between apps. Requires Accessibility access.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Displays

struct DisplaysTab: View {
    @ObservedObject var settings = Settings.shared

    var body: some View {
        Form {
            Section {
                Picker("Multiple displays", selection: $settings.displayMode) {
                    Text("Highlight the top window on every display").tag(DisplayMode.independent)
                    Text("Focus on one display — dim the others entirely").tag(DisplayMode.single)
                }
                .pickerStyle(.radioGroup)
            } footer: {
                Text("Independent mode gives each monitor its own focus. Single mode makes it obvious which screen you're working on by fully dimming the rest.")
            }

            Section {
                LabeledContent("Connected displays", value: "\(NSScreen.screens.count)")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Shortcuts

struct ShortcutsTab: View {
    @ObservedObject var manager = HotkeyManager.shared

    var body: some View {
        Form {
            Section {
                ForEach(HotkeyAction.allCases, id: \.self) { action in
                    LabeledContent(action.title) {
                        HStack(spacing: 6) {
                            ShortcutRecorderField(action: action)
                                .frame(width: 150, height: 24)
                            Button {
                                manager.setCombo(.none, for: action)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .disabled(!manager.combo(for: action).isSet)
                        }
                    }
                }
            } header: {
                Text("Global shortcuts")
            } footer: {
                Text("Click a field, then press the new shortcut. Esc cancels, Delete clears. Intensity shortcuts step by 10%.")
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Automation

struct AutomationTab: View {
    var body: some View {
        Form {
            Section {
                CodeRow(#"osascript -e 'tell application "OpenHaze" to set enabled to false'"#)
                CodeRow(#"osascript -e 'tell application "OpenHaze" to set intensity to 60'"#)
                CodeRow(#"osascript -e 'tell application "OpenHaze" to get intensity'"#)
            } header: {
                Text("AppleScript")
            } footer: {
                Text("The first run asks for automation permission. Use these from the Shortcuts app via “Run AppleScript”, or from any script.")
            }

            Section {
                CodeRow("open \"openhaze://toggle\"")
                CodeRow("open \"openhaze://on\"")
                CodeRow("open \"openhaze://off\"")
                CodeRow("open \"openhaze://intensity?value=60\"")
            } header: {
                Text("URL scheme")
            } footer: {
                Text("Works from Terminal, Raycast, Alfred, or Shortcuts’ “Open URLs” action.")
            }
        }
        .formStyle(.grouped)
    }
}

struct CodeRow: View {
    let code: String
    @StateObject private var copiedBox = StateBox(false)

    init(_ code: String) { self.code = code }

    var body: some View {
        HStack {
            Text(code)
                .font(.system(.caption, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(code, forType: .string)
                copiedBox.value = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak copiedBox] in
                    copiedBox?.value = false
                }
            } label: {
                Image(systemName: copiedBox.value ? "checkmark" : "doc.on.doc")
            }
            .buttonStyle(.borderless)
        }
    }
}

// MARK: - About

struct AboutTab: View {
    private var version: String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        return "Version \(v)"
    }

    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 96, height: 96)
            Text("OpenHaze")
                .font(.title.bold())
            Text(version)
                .foregroundStyle(.secondary)
            Text("Dims background windows so you can focus on the one that matters.")
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)
            Divider().frame(width: 240)
            Text("A personal, open-source recreation of HazeOver by Pointum.\nIf you love it, consider supporting the original:")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Link("hazeover.com", destination: URL(string: "https://hazeover.com")!)
                .font(.caption)
            Spacer()
        }
        .padding()
    }
}
