import AppKit

/// A full-screen, click-through, borderless window that provides the haze.
/// Two of these exist per display so focus changes can crossfade smoothly.
final class OverlayWindow: NSWindow {
    init(screenFrame: NSRect) {
        super.init(contentRect: screenFrame,
                   styleMask: .borderless,
                   backing: .buffered,
                   defer: false)
        isOpaque = false
        backgroundColor = .black
        hasShadow = false
        ignoresMouseEvents = true
        level = .normal
        // Keep haze on its desktop during Space animations instead of pinning it
        // over every Space. Reordering below a normal window can move it to the
        // active desktop; fullscreen plans never order it in. Transient windows
        // are hidden by Mission Control rather than appearing as desktop tiles.
        collectionBehavior = [.moveToActiveSpace, .transient, .ignoresCycle]
        animationBehavior = .none
        isReleasedWhenClosed = false
        isExcludedFromWindowsMenu = true
        hidesOnDeactivate = false
        alphaValue = 0
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
