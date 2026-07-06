# OpenHaze

A native macOS menu-bar utility that dims background windows so the one you're
working in stands out — an open-source, personal-use recreation of
[HazeOver](https://hazeover.com) (if you love the idea, support the original!).

Built with Swift + AppKit, no dependencies, ~1,700 lines.

## Features

| Feature | Status |
|---|---|
| Dim all background windows, front window stays bright | ✅ |
| Adjustable intensity, from soft shade to blackout (0–100%) | ✅ |
| Smooth GPU-accelerated crossfade on focus change, adjustable duration | ✅ |
| Highlight a single window **or** all windows of the front app | ✅ |
| Multi-display: independent focus per display, or dim other displays entirely | ✅ |
| Menu bar slider + **scroll over the icon** to adjust intensity | ✅ |
| ⌥-click or right-click the menu bar icon to toggle | ✅ |
| Global hotkeys: toggle (default ⌃⌥⌘H), increase/decrease intensity | ✅ |
| **Hold Fn** to temporarily reveal all windows (great while dragging) | ✅ |
| Desktop click reveals everything (or dims everything — your choice) | ✅ |
| Custom haze color | ✅ |
| Separate intensity & color for Light / Dark system appearance | ✅ |
| AppleScript: `tell application "OpenHaze" to set intensity to 60` | ✅ |
| URL scheme: `openhaze://toggle`, `openhaze://intensity?value=60` | ✅ |
| Start at login | ✅ |
| Works with Spaces & Mission Control | ✅ |
| Native fullscreen / Split View dimming | ❌ (haze pauses there) |
| Shortcuts-app native actions / Focus Filters | ❌ (use AppleScript/URL from Shortcuts instead) |

## Build & install

```bash
cd OpenHaze
./build.sh --install --run
```

That compiles with `swiftc` (plain Command Line Tools are enough — SwiftPM/Xcode
not required), assembles `build/OpenHaze.app`, ad-hoc signs it, copies it to
`~/Applications`, and launches it.

## First run

OpenHaze starts working immediately. It will offer to enable **Accessibility**
access (System Settings → Privacy & Security → Accessibility):

- **With it:** focus changes are detected instantly via Accessibility events,
  and the Fn-reveal gesture works.
- **Without it:** a lightweight window-list poll (~7×/sec, sub-millisecond) is
  used instead — everything still works, reactions are just up to ~150 ms slower.

> Because the app is ad-hoc signed, **rebuilding it invalidates the
> Accessibility grant**. After a rebuild, toggle OpenHaze off and on again in
> the Accessibility list (or remove and re-add it).

## Using it

- **Click** the menu bar icon → intensity slider, toggle, Settings.
- **Scroll** over the icon → adjust intensity live.
- **⌥-click / right-click** the icon → toggle dimming.
- **⌃⌥⌘H** → toggle dimming (rebindable in Settings → Shortcuts).
- **Hold Fn** → temporarily reveal all windows.
- **Click the wallpaper** → haze fades out (configurable).

Settings tabs: **General** (intensity, color, fade duration, per-appearance
settings, login item), **Focus** (single window vs. app windows, desktop
behavior, Fn reveal), **Displays** (independent vs. single-display focus),
**Shortcuts**, **Automation** (copy-paste examples), **About**.

## Automation

```bash
# AppleScript (first use asks for automation permission)
osascript -e 'tell application "OpenHaze" to set enabled to false'
osascript -e 'tell application "OpenHaze" to set intensity to 60'
osascript -e 'tell application "OpenHaze" to get intensity'

# URL scheme (Terminal, Raycast, Alfred, Shortcuts "Open URL")
open "openhaze://toggle"
open "openhaze://on"
open "openhaze://off"
open "openhaze://intensity?value=60"
```

## How it works

A borderless, click-through overlay window (two per display, for crossfading)
is inserted into the global window stack **directly beneath the focused
window** using `NSWindow.order(.below, relativeTo:)` with the target's window
number. Everything under the overlay is behind the haze; everything above —
the focused window, its sheets and popovers, floating panels, the Dock and
menu bar — stays bright. Focus is tracked with Accessibility events
(`AXObserver`) plus workspace notifications, with a cheap
`CGWindowListCopyWindowInfo` poll as a permission-free fallback and drift
corrector.

## Project layout

```
Sources/OpenHaze/
  main.swift              app entry
  AppDelegate.swift       wiring, URL scheme, AppleScript bridge
  Settings.swift          UserDefaults-backed preferences model
  HazeEngine.swift        per-display planning + overlay orchestration
  FocusTracker.swift      AX observers, workspace events, Fn key
  WindowSnapshot.swift    CGWindowList helpers
  OverlayWindow.swift     the haze window
  StatusItemController.swift  menu bar UI
  PreferencesWindow.swift SwiftUI settings tabs
  ShortcutRecorder.swift  hotkey recorder control
  HotkeyManager.swift     Carbon global hotkeys
  OnboardingWindow.swift  first-run / permission flow
  StateBox.swift          @State replacement (CLT lacks SwiftUI macros)
Support/                  Info.plist, sdef, icon generator
build.sh                  build + bundle + sign (+ --install --run)
```

## Known limitations

- Native fullscreen and Split View spaces are left undimmed (the haze pauses).
- If two apps' windows interleave in "app windows" mode, windows sitting
  between the front app's windows stay bright.
- Rebuilding requires re-granting Accessibility (ad-hoc signature changes).

## Uninstall

Quit from the menu bar, delete `~/Applications/OpenHaze.app`, and remove the
entry from System Settings → Accessibility. Settings live in
`defaults delete dev.openhaze.OpenHaze`.
