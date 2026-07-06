# OpenHaze for Windows

Dims background windows so the one you're working in stands out — the Windows
sibling of the Mac OpenHaze, both personal-use recreations of
[HazeOver](https://hazeover.com). Designed with **dual-monitor setups** in mind.

Single C# / WinForms app, ~1,400 lines, **zero dependencies**: it compiles with
the `csc.exe` that ships inside every Windows 10/11 install.

## Install on the RTX box

1. Copy this `OpenHaze-Windows` folder to the PC (USB, network share, cloud — anything).
2. Double-click **`build.bat`**. It compiles `OpenHaze.exe` in a second or two
   and offers to launch it.
3. That's it — no permission prompts, no SDK. Look for the amber-window icon in
   the tray (you may need to drag it out of the tray overflow).

If SmartScreen ever complains about the exe, that's because it's freshly built
and unsigned — "More info → Run anyway". You built it yourself from this source.

## Using it

| Action | Result |
|---|---|
| Click / right-click tray icon | Menu with intensity slider, toggle, Settings |
| **Double-click** tray icon | Toggle dimming on/off |
| **Scroll wheel over** tray icon | Adjust intensity (5% per notch) |
| **Ctrl+Alt+H** | Toggle dimming (rebindable) |
| Click the desktop | Haze fades out (configurable) |

## The two-monitor modes (Settings → Monitors)

- **Independent focus** — each monitor keeps its own top window bright.
  Good when you actively work on both screens.
- **One focused monitor** — the monitor with the active window behaves
  normally; the other monitor is dimmed *entirely*. This is the one to try
  first if you lose track of where your focus is: the lit monitor is always
  the one you're on.

Everything else is in Settings: intensity, fade duration, haze color,
active-window vs whole-app highlighting, desktop behavior, hotkeys,
start-with-Windows.

## How it works

Per monitor, two borderless, click-through, never-activated layered windows act
as the haze. `SetWinEventHook(EVENT_SYSTEM_FOREGROUND)` reports focus changes
instantly (no permissions needed on Windows), and the overlay is slotted into
the z-order **directly beneath the focused window** with
`SetWindowPos(overlay, hWndInsertAfter: foreground, …)`. Everything below the
overlay is hazed; the focused window, its dialogs, and the (topmost) taskbar
stay bright. A 200 ms poll corrects z-order drift, and the two overlays
crossfade on focus changes for a smooth HazeOver-style transition.

## Files

```
NativeMethods.cs   Win32 interop (z-order, WinEvent hook, hotkeys, mouse hook)
OpenHaze.cs        engine (per-monitor planning, crossfade), tray UI, hotkeys
SettingsForm.cs    settings window
app.manifest       Per-Monitor-V2 DPI awareness (mixed-DPI dual monitors)
build.bat          compiles with Windows' built-in csc.exe
```

Settings are stored at `%APPDATA%\OpenHaze\settings.txt`.

## Known limitations

- Exclusive-fullscreen games bypass the desktop compositor, so the haze
  neither shows over them nor interferes with them (borderless-fullscreen
  works normally).
- Windows of elevated (admin) apps may resist z-order placement; if dimming
  misbehaves around an admin tool, run OpenHaze as administrator too.
- No per-light/dark-theme intensity variants (the Mac version has this).

## Uninstall

Tray → Exit, delete the folder, and untick "Start with Windows" first (or
remove the `OpenHaze` value under
`HKCU\Software\Microsoft\Windows\CurrentVersion\Run`). Delete
`%APPDATA%\OpenHaze` if you want the settings gone too.
