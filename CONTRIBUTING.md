# Contributing to openhaze

Thanks for considering a contribution. Issues, discussions and PRs are all
welcome.

## Getting set up

macOS: `cd macos && ./build.sh` (plain Command Line Tools are enough).

Windows: run `windows\build.bat` (uses the csc.exe that ships with Windows;
no SDK needed).

## Running the checks

Build both platforms if you can; CI builds macOS and Windows on every PR. There is no unit-test suite (the app is a thin shell over OS window APIs); manual checks are described in each platform README.

## Ground rules

- Open an issue or discussion before large changes, so effort isn't wasted.
- Keep PRs focused: one change per PR.
- New behavior needs a test where the repo has a test suite.
- CI must pass before merge.

## Licensing

By contributing you agree your contributions are licensed under the repo's
MIT license.
