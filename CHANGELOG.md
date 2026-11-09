# Changelog

All notable changes to **OpenHaze** are documented here. This project adheres to [Semantic Versioning](https://semver.org/), and every version has a [GitHub release](https://github.com/jay739/openhaze/releases) with downloads for macOS and Windows. From 0.3.0 on, each release also carries `SHA256SUMS.txt`.

## [0.3.0] - 2026-11-09

OpenHaze now tells you when a new version is out, and upgrading on Windows no longer stops on a running copy.

- **Update notices on both platforms.** Once a day the app asks GitHub for the latest release. A newer one appears at the top of the menu bar or tray menu and is announced once, with a balloon on Windows and an alert on macOS, and either one opens the release page. Nothing is downloaded or installed automatically. "Check for updates" in the menu checks right away, and the daily check can be turned off in Settings.
- **The Windows installer closes a running OpenHaze by itself.** Setup used to list it as a blank entry, fail to close it, and then stop with "DeleteFile failed; code 5". OpenHaze now has a proper name in Windows, exits cleanly when an installer or a logoff asks it to, and Setup ends it as a last resort. The "Do not close the applications" option is gone, because it could only end in that error.
- **The macOS app passes strict signature checks again.** 0.2.2 hid the `.app` extension in the disk image, which stores Finder data on the app that `codesign --verify --strict` rejects. The extension is visible again, and packaging now runs the strict check itself.
- Releases now include `SHA256SUMS.txt` for checking the downloads.

## [0.2.2] - 2026-10-22

- The macOS disk image opens to a drag-to-install window drawn in the app's own colors.
- The Windows About box shows the real version instead of "1.0".

## [0.2.1] - 2026-10-19

- macOS apps in native fullscreen (the green button) are no longer dimmed. Thanks to @miaomiao-wzs for reporting this (#5) and contributing the fix (#6).

## [0.2.0] - 2026-09-19

- Windows: a UAC prompt or the lock screen now dims everything instead of nothing, and a fullscreen app dims the other monitors.
- Windows: a real installer with a Start Menu shortcut, an optional startup entry and an uninstaller replaces the renamed raw exe.
- A proper app icon for the exe, the installer, the landing page and the social preview.

## [0.1.0] - 2026-07-06

- First public release: window dimming for macOS and Windows.
