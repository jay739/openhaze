import AppKit
import SwiftUI
import Combine
import Carbon.HIToolbox

/// AppKit control that records a keyboard shortcut on click.
/// Esc cancels, Delete clears, anything with ⌘/⌥/⌃ (or an F-key) is accepted.
final class RecorderView: NSView {
    let action: HotkeyAction
    private var recording = false
    private var cancellable: AnyCancellable?

    init(action: HotkeyAction) {
        self.action = action
        super.init(frame: .zero)
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.borderWidth = 1
        cancellable = HotkeyManager.shared.$combos
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.needsDisplay = true }
    }

    required init?(coder: NSCoder) { fatalError() }

    override var intrinsicContentSize: NSSize { NSSize(width: 150, height: 24) }
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
    }

    override func becomeFirstResponder() -> Bool {
        recording = true
        needsDisplay = true
        return true
    }

    override func resignFirstResponder() -> Bool {
        recording = false
        needsDisplay = true
        return true
    }

    override func keyDown(with event: NSEvent) {
        guard recording else { super.keyDown(with: event); return }
        handle(event)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard recording, event.type == .keyDown else { return super.performKeyEquivalent(with: event) }
        handle(event)
        return true
    }

    override func flagsChanged(with event: NSEvent) {
        if recording { needsDisplay = true }
    }

    private func handle(_ event: NSEvent) {
        let keyCode = Int(event.keyCode)
        let mods = event.modifierFlags.intersection([.command, .option, .control, .shift])

        if keyCode == kVK_Escape && mods.isEmpty {
            endRecording()
            return
        }
        if (keyCode == kVK_Delete || keyCode == kVK_ForwardDelete) && mods.isEmpty {
            HotkeyManager.shared.setCombo(.none, for: action)
            endRecording()
            return
        }
        let isFunctionKey = (keyCode >= kVK_F1 && keyCode <= kVK_F12)
        guard !mods.intersection([.command, .option, .control]).isEmpty || isFunctionKey else {
            NSSound.beep()
            return
        }
        HotkeyManager.shared.setCombo(KeyCombo(keyCode: keyCode, modifiers: mods), for: action)
        endRecording()
    }

    private func endRecording() {
        window?.makeFirstResponder(nil)
    }

    override func draw(_ dirtyRect: NSRect) {
        layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        layer?.borderColor = recording
            ? NSColor.controlAccentColor.cgColor
            : NSColor.separatorColor.cgColor

        let text: String
        let color: NSColor
        if recording {
            var mods = ""
            let flags = NSEvent.modifierFlags
            if flags.contains(.control) { mods += "⌃" }
            if flags.contains(.option) { mods += "⌥" }
            if flags.contains(.shift) { mods += "⇧" }
            if flags.contains(.command) { mods += "⌘" }
            text = mods.isEmpty ? "Type shortcut…" : mods
            color = .secondaryLabelColor
        } else {
            let combo = HotkeyManager.shared.combo(for: action)
            text = combo.isSet ? combo.displayString : "Record Shortcut"
            color = combo.isSet ? .labelColor : .tertiaryLabelColor
        }

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 12),
            .foregroundColor: color,
        ]
        let size = text.size(withAttributes: attrs)
        let point = NSPoint(x: (bounds.width - size.width) / 2,
                            y: (bounds.height - size.height) / 2)
        text.draw(at: point, withAttributes: attrs)
    }
}

struct ShortcutRecorderField: NSViewRepresentable {
    let action: HotkeyAction

    func makeNSView(context: Context) -> RecorderView {
        RecorderView(action: action)
    }

    func updateNSView(_ nsView: RecorderView, context: Context) {}
}
