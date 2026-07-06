import AppKit
import Combine

/// What a given display's haze should be doing right now.
enum ScreenPlan: Equatable {
    case hidden                 // no dimming on this display
    case fullDim                // dim everything on this display (inactive display / desktop mode)
    case below(CGWindowID)      // dim everything behind this window
}

/// Per-display state: two overlay windows so plan changes can crossfade.
final class ScreenState {
    let displayID: CGDirectDisplayID
    var cgFrame: CGRect
    let overlayA: OverlayWindow
    let overlayB: OverlayWindow
    private var activeIsA = true

    var active: OverlayWindow { activeIsA ? overlayA : overlayB }
    var spare: OverlayWindow { activeIsA ? overlayB : overlayA }
    func swapActive() { activeIsA.toggle() }

    var plan: ScreenPlan = .hidden
    var transitionGeneration = 0
    var settledGeneration = 0

    init(screen: NSScreen) {
        displayID = screen.displayID
        cgFrame = screen.cgFrame
        overlayA = OverlayWindow(screenFrame: screen.frame)
        overlayB = OverlayWindow(screenFrame: screen.frame)
    }

    func updateFrame(for screen: NSScreen) {
        cgFrame = screen.cgFrame
        overlayA.setFrame(screen.frame, display: false)
        overlayB.setFrame(screen.frame, display: false)
    }

    func tearDown() {
        overlayA.orderOut(nil)
        overlayB.orderOut(nil)
    }
}

/// Core engine: decides, for every display, which window stays bright and keeps
/// the haze overlays ordered directly beneath it in the global window stack.
final class HazeEngine {
    private let settings: Settings
    let tracker = FocusTracker()

    private var states: [CGDirectDisplayID: ScreenState] = [:]
    private var pollTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var recomputeScheduled = false
    private var fastTransition = false   // next transition uses a quick fade (Fn reveal)

    init(settings: Settings) {
        self.settings = settings
    }

    // MARK: - Lifecycle

    func start() {
        rebuildScreens()

        tracker.onChange = { [weak self] in self?.scheduleRecompute() }
        tracker.onFnChanged = { [weak self] _ in
            guard let self, self.settings.fnReveal else { return }
            self.fastTransition = true
            self.scheduleRecompute()
        }
        tracker.start()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main) { [weak self] _ in
                self?.rebuildScreens()
                self?.scheduleRecompute()
        }

        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil, queue: .main) { [weak self] _ in
                // Give effectiveAppearance a beat to flip before re-reading settings.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self?.scheduleRecompute() }
        }

        settings.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.scheduleRecompute() }
            .store(in: &cancellables)

        restartPolling()
        recompute()
    }

    /// Called when Accessibility access was just granted.
    func accessibilityGranted() {
        tracker.refreshTrust()
        restartPolling()
        scheduleRecompute()
    }

    private func restartPolling() {
        pollTimer?.invalidate()
        // With AX events the poll is only a safety net; without them it is the
        // primary change detector, so it runs faster. Either way the work per
        // tick is a fraction of a millisecond.
        let interval: TimeInterval = AXIsProcessTrusted() ? 0.4 : 0.15
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.recompute()
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func rebuildScreens() {
        var seen = Set<CGDirectDisplayID>()
        for screen in NSScreen.screens {
            let id = screen.displayID
            seen.insert(id)
            if let state = states[id] {
                state.updateFrame(for: screen)
            } else {
                states[id] = ScreenState(screen: screen)
            }
        }
        for (id, state) in states where !seen.contains(id) {
            state.tearDown()
            states.removeValue(forKey: id)
        }
    }

    private func overlayNumbers() -> Set<CGWindowID> {
        var set = Set<CGWindowID>()
        for state in states.values {
            if state.overlayA.windowNumber > 0 { set.insert(CGWindowID(state.overlayA.windowNumber)) }
            if state.overlayB.windowNumber > 0 { set.insert(CGWindowID(state.overlayB.windowNumber)) }
        }
        return set
    }

    // MARK: - Planning

    func scheduleRecompute() {
        guard !recomputeScheduled else { return }
        recomputeScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.recomputeScheduled = false
            self.recompute()
        }
    }

    func recompute() {
        let snapshot = WindowSnapshot()
        let plans = computePlans(snapshot: snapshot)
        let duration = fastTransition ? min(0.12, settings.animationDuration) : settings.animationDuration
        fastTransition = false
        for (id, state) in states {
            apply(plans[id] ?? .hidden, to: state, snapshot: snapshot, duration: duration)
        }
    }

    private func computePlans(snapshot: WindowSnapshot) -> [CGDirectDisplayID: ScreenPlan] {
        var plans: [CGDirectDisplayID: ScreenPlan] = [:]
        let revealed = tracker.fnHeld && settings.fnReveal
        guard settings.enabled, !revealed else {
            for id in states.keys { plans[id] = .hidden }
            return plans
        }

        let excluded = overlayNumbers()
        let normals = snapshot.normalWindows(excluding: excluded)
        let frontPID = NSWorkspace.shared.frontmostApplication?.processIdentifier

        // The focused window: exact answer via Accessibility when available,
        // otherwise the front app's topmost normal window from the window list.
        var focused: WindowInfo?
        if let axID = tracker.focusedWindowID(), let w = normals.first(where: { $0.id == axID }) {
            focused = w
        } else if let pid = frontPID {
            focused = normals.first { $0.pid == pid }
        }
        // If we ourselves were activated without any window to show (URL scheme,
        // scripting), keep highlighting whatever is visually on top instead of
        // treating it like a desktop click.
        if focused == nil, frontPID == getpid() {
            focused = normals.first
        }

        // Screens covered by a non-normal-layer fullscreen window of the front
        // app (native fullscreen). Never dim those.
        var fullscreenScreens = Set<CGDirectDisplayID>()
        if let pid = frontPID {
            for (id, state) in states {
                let covering = snapshot.windows.contains {
                    $0.pid == pid && $0.layer != 0 && !excluded.contains($0.id) &&
                    $0.bounds.intersection(state.cgFrame).area >= state.cgFrame.area * 0.9
                }
                if covering { fullscreenScreens.insert(id) }
            }
        }

        guard let focused else {
            // Desktop focused (or nothing we can see, e.g. a fullscreen space).
            for (id, _) in states {
                if fullscreenScreens.contains(id) {
                    plans[id] = .hidden
                } else {
                    plans[id] = settings.desktopMode == .dimAll ? .fullDim : .hidden
                }
            }
            return plans
        }

        let focusedScreenID = states.first { $0.value.cgFrame.contains(CGPoint(x: focused.bounds.midX, y: focused.bounds.midY)) }?.key
            ?? states.keys.first

        for (id, state) in states {
            if fullscreenScreens.contains(id) {
                plans[id] = .hidden
                continue
            }
            let onScreen = normals.filter { $0.isOn(cgScreenFrame: state.cgFrame) }
            let isFocusedScreen = (id == focusedScreenID)

            switch settings.displayMode {
            case .single:
                plans[id] = isFocusedScreen
                    ? anchorPlan(onScreen: onScreen, highlight: focused)
                    : .fullDim
            case .independent:
                if isFocusedScreen {
                    plans[id] = anchorPlan(onScreen: onScreen, highlight: focused)
                } else if let localTop = onScreen.first {
                    plans[id] = anchorPlan(onScreen: onScreen, highlight: localTop)
                } else {
                    plans[id] = .hidden   // empty display: nothing to dim
                }
            }
        }
        return plans
    }

    /// The overlay anchor for one display: directly below the highlighted window,
    /// or below the bottom-most window of its app in "app windows" mode.
    private func anchorPlan(onScreen: [WindowInfo], highlight: WindowInfo) -> ScreenPlan {
        switch settings.highlightMode {
        case .window:
            return .below(highlight.id)
        case .app:
            let appWindows = onScreen.filter { $0.pid == highlight.pid }
            return .below(appWindows.last?.id ?? highlight.id)
        }
    }

    // MARK: - Applying plans

    private func apply(_ plan: ScreenPlan, to state: ScreenState, snapshot: WindowSnapshot, duration: TimeInterval) {
        let intensity = CGFloat(settings.currentIntensity)
        let color = settings.currentColor
        for overlay in [state.overlayA, state.overlayB] where overlay.backgroundColor != color {
            overlay.backgroundColor = color
        }

        if plan == state.plan {
            if case .below(let anchor) = plan {
                fixDriftIfNeeded(state: state, anchor: anchor, snapshot: snapshot)
            }
            // Track intensity/color scrubbing without a structural transition.
            if state.transitionGeneration == state.settledGeneration,
               plan != .hidden,
               abs(state.active.alphaValue - intensity) > 0.002 {
                animateAlpha(state.active, to: intensity, duration: 0.08)
            }
            return
        }

        state.plan = plan
        state.transitionGeneration &+= 1
        let gen = state.transitionGeneration

        switch plan {
        case .hidden:
            let outgoing = state.active
            animateAlpha(outgoing, to: 0, duration: duration) { [weak state] in
                guard let state, state.transitionGeneration == gen else { return }
                outgoing.orderOut(nil)
                state.settledGeneration = gen
            }

        case .fullDim, .below:
            let incoming = state.spare
            let outgoing = state.active
            animateAlpha(incoming, to: 0, duration: 0)   // cancel any in-flight fade
            if case .below(let anchor) = plan {
                incoming.order(.below, relativeTo: Int(anchor))
            } else {
                incoming.orderFrontRegardless()
            }
            state.swapActive()
            animateAlpha(incoming, to: intensity, duration: duration)
            animateAlpha(outgoing, to: 0, duration: duration) { [weak state] in
                guard let state, state.transitionGeneration == gen else { return }
                outgoing.orderOut(nil)
                state.settledGeneration = gen
            }
        }
    }

    /// If the active overlay ended up ABOVE its anchor (the anchor would be
    /// dimmed), push it back underneath. Benign drift — extra windows sitting
    /// above the overlay — is left alone to avoid re-ordering churn.
    private func fixDriftIfNeeded(state: ScreenState, anchor: CGWindowID, snapshot: WindowSnapshot) {
        guard let anchorIndex = snapshot.index(of: anchor) else { return }
        let overlayID = CGWindowID(state.active.windowNumber)
        guard let overlayIndex = snapshot.index(of: overlayID) else {
            state.active.order(.below, relativeTo: Int(anchor))
            return
        }
        if overlayIndex < anchorIndex {
            state.active.order(.below, relativeTo: Int(anchor))
        }
    }

    private func animateAlpha(_ window: NSWindow, to value: CGFloat,
                              duration: TimeInterval, completion: (() -> Void)? = nil) {
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = max(0, duration)
            ctx.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            window.animator().alphaValue = value
        }, completionHandler: completion)
    }
}

private extension CGRect {
    var area: CGFloat { max(0, width) * max(0, height) }
}
