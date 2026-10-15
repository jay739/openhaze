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
exit(failures == 0 ? 0 : 1)
