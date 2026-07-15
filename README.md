# OpenHaze

Dim background windows. Focus on the one that matters.

OpenHaze highlights your active window by fading everything behind it into an adjustable haze, from a soft shade to a total blackout. It is an open-source recreation of the excellent [HazeOver](https://hazeover.com) for macOS, plus a native Windows sibling that HazeOver never had.

Both implementations are small, dependency-free, and native:

|             | macOS                               | Windows                              |
| ----------- | ----------------------------------- | ------------------------------------ |
| Code        | Swift + AppKit, ~1,700 lines        | C# + WinForms, ~1,400 lines          |
| Builds with | plain Command Line Tools (`swiftc`) | the `csc.exe` bundled inside Windows |
| Get started | [`macos/`](macos/)                  | [`windows/`](windows/)               |

## Features

- Dim all background windows; the front window stays bright
- Adjustable intensity (0 to 100%) with smooth crossfade transitions
- Highlight a single window or all windows of the front app
- Multi-monitor modes: independent focus per display, or one lit display with the rest fully dimmed
- Menu bar / tray slider, and scroll over the icon to adjust intensity
- Global hotkeys (toggle, intensity up/down)
- Custom haze color, desktop-click reveal, launch at login
- macOS extras: Fn-to-reveal gesture, separate Light/Dark appearance settings, AppleScript + `openhaze://` URL scheme automation

## Install

Grab a build from the [releases page](https://github.com/jay739/openhaze/releases), or build from source in seconds:

```bash
# macOS
cd macos && ./build.sh --install --run

# Windows: double-click windows\build.bat, or from a terminal:
cd windows && build.bat
```

## Settings users can change

All settings live in the tray/menu-bar UI; nothing needs a config file edit.

| Setting                                                           | Where it is stored                                                                 |
| ----------------------------------------------------------------- | ---------------------------------------------------------------------------------- |
| Intensity, haze color, per-monitor mode, hotkeys, launch at login | macOS: standard `defaults` preferences. Windows: `%APPDATA%\OpenHaze\settings.txt` |

## How it works

The trick is the same on both platforms: full-screen, click-through overlay windows are inserted into the global z-order directly beneath the focused window (`NSWindow.order(.below, relativeTo:)` on macOS, `SetWindowPos(overlay, hWndInsertAfter: foreground, ...)` on Windows). Everything below the overlay is hazed; the focused window and everything above it stays bright. Two overlays per display crossfade for smooth transitions. Focus changes come from Accessibility events (macOS) or `SetWinEventHook` (Windows), with a cheap window-list poll as a fallback and drift corrector.

## Credit

Inspired by, and a tribute to, [HazeOver by Pointum](https://hazeover.com). This project reimplements the concept from scratch for personal use and shares no code or assets with the original. If you like the idea, buy HazeOver.

## Contributing and security

See [CONTRIBUTING.md](CONTRIBUTING.md). Report vulnerabilities privately per [SECURITY.md](SECURITY.md).

## License

[MIT](LICENSE)
