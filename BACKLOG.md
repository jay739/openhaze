# Backlog

Work on OpenHaze that is understood well enough to start without digging back through old PRs. Items are ordered by how much it hurts to leave them undone, not by effort. Finished items are removed once the release that carries them ships. GitHub Issues are for anything that needs discussion with users; this file is the working queue.

## B-1: Prove the Windows upgrade over a running copy

- **Status:** open
- **Size:** S
- **Touches:** `windows/installer.iss` (`CloseApplications`, the `[Code]` `CurPageChanged` hook), `windows/OpenHaze.cs` (`HotkeyWindow.WndProc`)
- **Why:** 0.3.0's fix was verified by asking Restart Manager to close the app directly, and the installer script only compiles in CI. Nobody has clicked through a real upgrade yet. If the `[Code]` hook misfires, "Do not close the applications" comes back and an upgrade over a running copy fails with "DeleteFile failed; code 5", as it did in 0.2.2.
- **Done when:** installing over a running 0.2.x closes it without an error, and installing over a running 0.3.0 lists "OpenHaze", offers only "Automatically close", closes it cleanly and relaunches it from the last page.

## B-2: Finish the hands-on checks from PR #4

- **Status:** open
- **Size:** S
- **Touches:** `windows/OpenHaze.cs` (the secure-desktop branch using `Native.IsSecureDesktopActive`, `IsFullscreenOnMonitor`), `windows/installer.iss`
- **Why:** the UAC and fullscreen fixes shipped in 0.2.0 without a test on a real desktop, and the installer's Start Menu and uninstall entries were never checked. A regression in either is invisible in CI.
- **Done when:** a UAC prompt full-dims every monitor, a fullscreen game dims the other monitors, and the Start Menu shortcut, the Installed apps entry and uninstalling all work.

## B-3: See the update notices on screen

- **Status:** open
- **Size:** S
- **Touches:** `windows/OpenHaze.cs` (`TrayContext.CheckForUpdates`, `OnUpdateCheckFinished`), `macos/Sources/OpenHaze/StatusItemController.swift` (`checkForUpdates`, `offerUpdate`)
- **Why:** the version comparison and parsing are covered by `windows/test.bat` and `macos/test.sh`, and both platforms were run against GitHub, but the menu item, the Windows balloon and the macOS alert have not been looked at.
- **Done when:** a build stamped older than the latest release (`OPENHAZE_VERSION=0.2.9` for `build.bat`, or `CFBundleShortVersionString` 0.2.9 in `macos/Support/Info.plist`) shows "Update available" in the menu and one notice that opens the release page, and "Check for updates" on a current build says it is up to date.

## B-4: Move off hdiutil before macOS drops it

- **Status:** open
- **Size:** M
- **Touches:** `macos/package-dmg.sh` (the `dmgbuild` call and the `hdiutil attach` in the signature check), the pinned `dmgbuild==1.6.7`
- **Why:** macOS 27 warns that `hdiutil create`, `attach`, `convert` and `imageinfo` are deprecated in favour of `diskutil image`. If a later macOS or runner image removes them, release packaging breaks on the tag push. Risk: changing the tool changes how the image is written, so a careless switch can quietly lose the Finder layout or the signature check.
- **Done when:** packaging runs without hdiutil (or dmgbuild gains a `diskutil image` backend and the pin is bumped), and the window layout and `codesign --verify --deep --strict` still pass.

## B-5: Point the Windows README at the installer

- **Status:** open
- **Size:** XS
- **Touches:** `windows/README.md`
- **Why:** it still tells people to copy an `OpenHaze-Windows` folder and double-click `build.bat`, but every release since 0.2.0 ships `OpenHaze-x.y.z-Setup.exe`.
- **Done when:** the README leads with the installer from the Releases page, keeps `build.bat` as the from-source route, and has no em dashes left (7 today).

## B-6: Clear the Swift compiler warnings in the settings window

- **Status:** open
- **Size:** XS
- **Touches:** `macos/Sources/OpenHaze/PreferencesWindow.swift` (the `Timer.publish(...).autoconnect()` property in `GeneralTab`, the `[weak copiedBox]` capture in `CodeRow`)
- **Why:** Swift 6.4 warns about both. Under a stricter language mode they can become errors and stop the build.
- **Done when:** `./build.sh` on the newest Xcode prints no warnings.

## B-7: Clean the remaining em dashes

- **Status:** open
- **Size:** XS
- **Touches:** `macos/README.md` (6), `macos/Support/makeicon.swift` (2), `macos/Sources/OpenHaze/OnboardingWindow.swift` (2), `macos/Sources/OpenHaze/HazeEngine.swift` (2), `macos/build.sh` (1), plus `windows/README.md` under B-5
- **Why:** the house style has no em dashes. Each file is cleaned in the same change the next time it is edited for another reason, so this item shrinks on its own.
- **Done when:** `git grep -P '\x{2014}'` finds nothing.
