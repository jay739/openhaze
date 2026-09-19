# OpenHaze for Windows

Dims background windows so the one you're working in stands out — the Windows
sibling of the Mac OpenHaze, both personal-use recreations of
[HazeOver](https://hazeover.com). Designed with **dual-monitor setups** in mind.

Single C# / WinForms app, ~1,400 lines, **zero dependencies**: it compiles with
the `csc.exe` that ships inside every Windows 10/11 install.

## Install

Download `OpenHaze-<version>-Setup.exe` from the
[latest release](https://github.com/jay739/openhaze/releases/latest) and run
it. It's a real installer (Start Menu shortcut, optional desktop shortcut,
optional "start with Windows", proper entry in Add/Remove Programs) that
installs per-user, so it never asks for admin rights.

If SmartScreen complains, that's because the binary is unsigned, not
malicious — "More info → Run anyway".

## Build it yourself

1. Copy this `OpenHaze-Windows` folder to the PC (USB, network share, cloud — anything).
2. Double-click **`build.bat`**. It compiles `OpenHaze.exe` in a second or two
   and offers to launch it.
3. That's it — no permission prompts, no SDK. Look for the amber-window icon in
   the tray (you may need to drag it out of the tray overflow).

This produces a portable `OpenHaze.exe` you can run from anywhere; it's the
same zero-dependency path CI uses to build the release installer.

## Using it

| Action                          | Result                                       |
| ------------------------------- | -------------------------------------------- |
| Click / right-click tray icon   | Menu with intensity slider, toggle, Settings |
| **Double-click** tray icon      | Toggle dimming on/off                        |
| **Scroll wheel over** tray icon | Adjust intensity (5% per notch)              |
| **Ctrl+Alt+H**                  | Toggle dimming (rebindable)                  |
| Click the desktop               | Haze fades out (configurable)                |

## The two-monitor modes (Settings → Monitors)

- **Independent focus** — each monitor keeps its own top window bright.
  Good when you actively work on both screens.
- **One focused monitor** — the monitor with the active window behaves
  normally; the other monitor is dimmed _entirely_. This is the one to try
  first if you lose track of where your focus is: the lit monitor is always
  the one you're on.

A fullscreen window (a game, a video — anything covering its whole monitor,
taskbar included) dims the other monitors entirely regardless of which mode
is selected, the same as **One focused monitor** would.

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

A UAC consent prompt (or the lock screen / Ctrl+Alt+Del screen) runs on a
separate, isolated "secure desktop" that OpenHaze can't draw on or even see
into. Rather than reading that as "nothing is focused" and doing nothing,
OpenHaze detects the switch (`OpenInputDesktop` failing is the standard tell)
and dims everything on the interactive desktop until control returns.

## Files

```
NativeMethods.cs    Win32 interop (z-order, WinEvent hook, hotkeys, mouse hook)
OpenHaze.cs         engine (per-monitor planning, crossfade), tray UI, hotkeys
SettingsForm.cs     settings window
app.manifest        Per-Monitor-V2 DPI awareness (mixed-DPI dual monitors)
build.bat           compiles with Windows' built-in csc.exe
installer.iss       Inno Setup script; CI compiles this into the release Setup.exe
Support/AppIcon.ico app/installer icon (Support/makeicon.py regenerates it)
```

Settings are stored at `%APPDATA%\OpenHaze\settings.txt`.

## Known limitations

- Exclusive-fullscreen games bypass the desktop compositor, so the haze
  neither shows over them nor interferes with them on their own monitor
  (borderless-fullscreen works normally there too). Either kind of fullscreen
  still dims the _other_ monitors correctly, since that only needs the
  window's reported bounds, not compositing.
- Windows of elevated (admin) apps may resist z-order placement; if dimming
  misbehaves around an admin tool, run OpenHaze as administrator too. This is
  separate from the UAC consent prompt itself, which is handled (see above).
- No per-light/dark-theme intensity variants (the Mac version has this).

## Uninstall

Installed via the Setup.exe: Settings → Apps → OpenHaze → Uninstall (it also
unregisters "start with Windows" for you).

Built yourself via `build.bat`: Tray → Exit, delete the folder, and untick
"Start with Windows" first (or remove the `OpenHaze` value under
`HKCU\Software\Microsoft\Windows\CurrentVersion\Run`). Delete
`%APPDATA%\OpenHaze` if you want the settings gone too.
