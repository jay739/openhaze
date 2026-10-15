import AppKit

var failures = 0
func check(_ name: String, _ actual: Set<CGDirectDisplayID>, _ expected: Set<CGDirectDisplayID>) {
    if actual == expected { print("PASS: \(name)") }
    else { failures += 1; print("FAIL: \(name): expected \(expected.sorted()), got \(actual.sorted())") }
}
let left = CGRect(x: 0, y: 0, width: 1440, height: 900)
let right = CGRect(x: 1440, y: 0, width: 1440, height: 900)
func window(_ id: CGWindowID = 42, pid: pid_t = 123, layer: Int = 0,
            bounds: CGRect = left) -> WindowInfo {
    WindowInfo(id: id, pid: pid, layer: layer, bounds: bounds, alpha: 1)
}
func detect(_ windows: [WindowInfo], fullscreen: Bool,
            focused: CGWindowID? = 42, pid: pid_t? = 123,
            screens: [CGDirectDisplayID: CGRect] = [1: left],
            excluding: Set<CGWindowID> = []) -> Set<CGDirectDisplayID> {
    FullscreenDetection.screenIDs(windows: windows, frontPID: pid,
        focusedWindowID: focused, focusedWindowIsFullscreen: fullscreen,
        screens: screens, excluding: excluding)
}
check("native fullscreen at layer 0", detect([window()], fullscreen: true), [1])
check("ordinary maximized window stays dimmable", detect([window()], fullscreen: false), [])
check("ordinary floating window stays dimmable", detect([window(bounds: CGRect(x:100,y:100,width:900,height:600))], fullscreen: false), [])
check("fullscreen only suspends its own display", detect([window(bounds:right)], fullscreen:true, screens:[1:left,2:right]), [2])
check("window-list fallback preserves nonzero-layer fullscreen", detect([window(layer:3)], fullscreen:false), [1])
check("overlay cannot count as fullscreen", detect([window(layer:3)], fullscreen:false, excluding:[42]), [])
check("background app cannot count as fullscreen", detect([window(pid:456,layer:3)], fullscreen:false), [])
check("no front app", detect([window()], fullscreen:true, pid:nil), [])
check("fullscreen without a CG window during transition", detect([], fullscreen:true, focused:nil), [1])
check("missing CG window does not guess across displays", detect([], fullscreen:true, focused:nil, screens:[1:left,2:right]), [])
check("fullscreen can use a visible front-app window without its AX ID", detect([window(bounds:right)], fullscreen:true, focused:nil, screens:[1:left,2:right]), [2])
check("exit fullscreen resumes ordinary dimming", detect([window()], fullscreen:false), [])
let app = NSApplication.shared
let overlay = OverlayWindow(screenFrame: left)
if overlay.collectionBehavior.contains(.fullScreenAuxiliary) {
    failures += 1; print("FAIL: overlay must not join native fullscreen as an auxiliary window")
} else { print("PASS: overlay does not join native fullscreen as an auxiliary window") }
overlay.orderOut(nil)

func expect(_ name: String, _ condition: Bool) {
    if condition { print("PASS: \(name)") }
    else { failures += 1; print("FAIL: \(name)") }
}
if let screen = NSScreen.screens.first {
    let state = ScreenState(screen: screen)
    let engine = HazeEngine(settings: Settings.shared)
    state.plan = .below(42)
    state.transitionGeneration = 3
    state.settledGeneration = 2
    state.overlayA.alphaValue = 0.65
    state.overlayB.alphaValue = 0.45
    state.overlayA.orderFrontRegardless()
    state.overlayB.orderFrontRegardless()
    expect("crossfade fixture starts with both windows visible",
           state.overlayA.isVisible && state.overlayB.isVisible)
    engine.apply(.fullscreen, to: state, snapshot: WindowSnapshot(), duration: 5)
    expect("fullscreen immediately clears both crossfade alpha values",
           state.overlayA.alphaValue == 0 && state.overlayB.alphaValue == 0)
    expect("fullscreen removes both overlay windows",
           !state.overlayA.isVisible && !state.overlayB.isVisible)
    expect("fullscreen invalidates pending crossfade generations",
           state.transitionGeneration > 3 && state.settledGeneration == state.transitionGeneration)
    expect("fullscreen uses its own immediate plan", state.plan == .fullscreen)
    let generation = state.transitionGeneration
    engine.apply(.fullscreen, to: state, snapshot: WindowSnapshot(), duration: 5)
    expect("repeated fullscreen refresh does not restart transitions",
           state.transitionGeneration == generation)
    state.overlayA.alphaValue = 0.65
    state.overlayB.alphaValue = 0.45
    state.suspendImmediately()
    expect("Space change immediately clears both overlays before focus refresh",
           state.plan == .hidden && state.overlayA.alphaValue == 0 && state.overlayB.alphaValue == 0)
    engine.apply(.fullDim, to: state, snapshot: WindowSnapshot(), duration: 2)
    engine.apply(.fullscreen, to: state, snapshot: WindowSnapshot(), duration: 2)
    RunLoop.main.run(until: Date().addingTimeInterval(0.1))
    expect("pending fade-in cannot reshow a fullscreen overlay",
           !state.overlayA.isVisible && !state.overlayB.isVisible)
    expect("pending fade-in cannot restore fullscreen haze opacity",
           state.overlayA.alphaValue == 0 && state.overlayB.alphaValue == 0)
    state.tearDown()
} else {
    failures += 1
    print("FAIL: overlay-transition checks require a logged-in macOS graphical session")
}
exit(failures == 0 ? 0 : 1)
