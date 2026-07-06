import AppKit
import SwiftUI
import Combine

final class OnboardingWindowController {
    static let shared = OnboardingWindowController()
    /// Called once Accessibility access flips to granted.
    var onGranted: (() -> Void)?
    private var window: NSWindow?

    func show() {
        if window == nil {
            let host = NSHostingController(rootView: OnboardingView(
                onGranted: { [weak self] in self?.onGranted?() },
                close: { [weak self] in self?.window?.close() }
            ))
            let w = NSWindow(contentViewController: host)
            w.styleMask = [.titled, .closable]
            w.title = "Welcome to OpenHaze"
            w.isReleasedWhenClosed = false
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct OnboardingView: View {
    let onGranted: () -> Void
    let close: () -> Void

    @StateObject private var trustedBox = StateBox(AXIsProcessTrusted())
    private var trusted: Bool { trustedBox.value }
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "rectangle.inset.filled.on.rectangle")
                .font(.system(size: 44))
                .foregroundStyle(.tint)
            Text("Welcome to OpenHaze")
                .font(.title2.bold())
            Text("OpenHaze highlights the window you're working in and gently dims everything else. It's already running — try clicking between a few windows.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            GroupBox {
                HStack(spacing: 10) {
                    Image(systemName: trusted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundStyle(trusted ? .green : .orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Accessibility access").font(.headline)
                        Text(trusted
                             ? "Granted — focus changes are detected instantly."
                             : "Recommended: makes dimming react instantly to focus changes and enables the Fn-reveal gesture. OpenHaze works without it too, just slightly less snappily.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                }
                .padding(4)
            }

            HStack {
                if !trusted {
                    Button("Grant Accessibility Access") {
                        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
                        AXIsProcessTrustedWithOptions(options)
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
                Button(trusted ? "Start Using OpenHaze" : "Continue Without It") {
                    close()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 460)
        .onReceive(timer) { _ in
            let now = AXIsProcessTrusted()
            if now != trustedBox.value {
                trustedBox.value = now
                if now { onGranted() }
            }
        }
    }
}
