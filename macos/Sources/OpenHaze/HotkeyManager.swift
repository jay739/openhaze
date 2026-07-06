import AppKit
import Carbon.HIToolbox

/// A recorded keyboard shortcut. keyCode == -1 means "none".
struct KeyCombo: Equatable {
    var keyCode: Int
    var modifiers: NSEvent.ModifierFlags

    static let none = KeyCombo(keyCode: -1, modifiers: [])
    var isSet: Bool { keyCode >= 0 }

    var carbonModifiers: UInt32 {
        var flags: UInt32 = 0
        if modifiers.contains(.command) { flags |= UInt32(cmdKey) }
        if modifiers.contains(.option) { flags |= UInt32(optionKey) }
        if modifiers.contains(.control) { flags |= UInt32(controlKey) }
        if modifiers.contains(.shift) { flags |= UInt32(shiftKey) }
        return flags
    }

    var displayString: String {
        guard isSet else { return "" }
        var s = ""
        if modifiers.contains(.control) { s += "⌃" }
        if modifiers.contains(.option) { s += "⌥" }
        if modifiers.contains(.shift) { s += "⇧" }
        if modifiers.contains(.command) { s += "⌘" }
        return s + KeyCombo.keyName(for: keyCode)
    }

    static func keyName(for keyCode: Int) -> String {
        let special: [Int: String] = [
            kVK_Return: "↩", kVK_Tab: "⇥", kVK_Space: "Space", kVK_Delete: "⌫",
            kVK_Escape: "⎋", kVK_ForwardDelete: "⌦", kVK_Home: "↖", kVK_End: "↘",
            kVK_PageUp: "⇞", kVK_PageDown: "⇟", kVK_LeftArrow: "←", kVK_RightArrow: "→",
            kVK_DownArrow: "↓", kVK_UpArrow: "↑",
            kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5",
            kVK_F6: "F6", kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10",
            kVK_F11: "F11", kVK_F12: "F12",
        ]
        if let name = special[keyCode] { return name }

        let letters: [Int: String] = [
            kVK_ANSI_A: "A", kVK_ANSI_B: "B", kVK_ANSI_C: "C", kVK_ANSI_D: "D",
            kVK_ANSI_E: "E", kVK_ANSI_F: "F", kVK_ANSI_G: "G", kVK_ANSI_H: "H",
            kVK_ANSI_I: "I", kVK_ANSI_J: "J", kVK_ANSI_K: "K", kVK_ANSI_L: "L",
            kVK_ANSI_M: "M", kVK_ANSI_N: "N", kVK_ANSI_O: "O", kVK_ANSI_P: "P",
            kVK_ANSI_Q: "Q", kVK_ANSI_R: "R", kVK_ANSI_S: "S", kVK_ANSI_T: "T",
            kVK_ANSI_U: "U", kVK_ANSI_V: "V", kVK_ANSI_W: "W", kVK_ANSI_X: "X",
            kVK_ANSI_Y: "Y", kVK_ANSI_Z: "Z",
            kVK_ANSI_0: "0", kVK_ANSI_1: "1", kVK_ANSI_2: "2", kVK_ANSI_3: "3",
            kVK_ANSI_4: "4", kVK_ANSI_5: "5", kVK_ANSI_6: "6", kVK_ANSI_7: "7",
            kVK_ANSI_8: "8", kVK_ANSI_9: "9",
            kVK_ANSI_Minus: "-", kVK_ANSI_Equal: "=", kVK_ANSI_LeftBracket: "[",
            kVK_ANSI_RightBracket: "]", kVK_ANSI_Backslash: "\\", kVK_ANSI_Semicolon: ";",
            kVK_ANSI_Quote: "'", kVK_ANSI_Comma: ",", kVK_ANSI_Period: ".",
            kVK_ANSI_Slash: "/", kVK_ANSI_Grave: "`",
        ]
        return letters[keyCode] ?? "key \(keyCode)"
    }
}

enum HotkeyAction: String, CaseIterable {
    case toggle
    case increase
    case decrease

    var title: String {
        switch self {
        case .toggle: return "Toggle dimming"
        case .increase: return "Increase intensity"
        case .decrease: return "Decrease intensity"
        }
    }

    var defaultCombo: KeyCombo {
        switch self {
        case .toggle: return KeyCombo(keyCode: kVK_ANSI_H, modifiers: [.control, .option, .command])
        case .increase, .decrease: return .none
        }
    }

    var carbonID: UInt32 {
        switch self {
        case .toggle: return 1
        case .increase: return 2
        case .decrease: return 3
        }
    }
}

/// Registers global hotkeys via Carbon (no special permissions required).
final class HotkeyManager: ObservableObject {
    static let shared = HotkeyManager()

    @Published private(set) var combos: [HotkeyAction: KeyCombo] = [:]

    private var hotkeyRefs: [EventHotKeyRef?] = []
    private var handlerInstalled = false
    private let signature: OSType = 0x4F485A4B  // 'OHZK'

    private init() {
        for action in HotkeyAction.allCases {
            combos[action] = loadCombo(for: action)
        }
    }

    func start() {
        installHandlerIfNeeded()
        registerAll()
    }

    func setCombo(_ combo: KeyCombo, for action: HotkeyAction) {
        combos[action] = combo
        let d = UserDefaults.standard
        d.set(combo.keyCode, forKey: "hotkey.\(action.rawValue).keyCode")
        d.set(Int(combo.modifiers.rawValue), forKey: "hotkey.\(action.rawValue).modifiers")
        registerAll()
    }

    func combo(for action: HotkeyAction) -> KeyCombo {
        combos[action] ?? .none
    }

    private func loadCombo(for action: HotkeyAction) -> KeyCombo {
        let d = UserDefaults.standard
        guard d.object(forKey: "hotkey.\(action.rawValue).keyCode") != nil else {
            return action.defaultCombo
        }
        let keyCode = d.integer(forKey: "hotkey.\(action.rawValue).keyCode")
        let mods = NSEvent.ModifierFlags(rawValue: UInt(d.integer(forKey: "hotkey.\(action.rawValue).modifiers")))
        return KeyCombo(keyCode: keyCode, modifiers: mods)
    }

    private func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ -> OSStatus in
            var hotkeyID = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &hotkeyID)
            DispatchQueue.main.async {
                HotkeyManager.shared.perform(id: hotkeyID.id)
            }
            return noErr
        }, 1, &spec, nil, nil)
    }

    private func registerAll() {
        for ref in hotkeyRefs {
            if let ref { UnregisterEventHotKey(ref) }
        }
        hotkeyRefs.removeAll()

        for action in HotkeyAction.allCases {
            let combo = combo(for: action)
            guard combo.isSet else { continue }
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: signature, id: action.carbonID)
            RegisterEventHotKey(UInt32(combo.keyCode), combo.carbonModifiers, id,
                                GetApplicationEventTarget(), 0, &ref)
            hotkeyRefs.append(ref)
        }
    }

    private func perform(id: UInt32) {
        let settings = Settings.shared
        switch id {
        case HotkeyAction.toggle.carbonID:
            settings.enabled.toggle()
        case HotkeyAction.increase.carbonID:
            settings.setCurrentIntensity(settings.currentIntensity + 0.1)
        case HotkeyAction.decrease.carbonID:
            settings.setCurrentIntensity(settings.currentIntensity - 0.1)
        default:
            break
        }
    }
}
