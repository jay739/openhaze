#!/bin/bash
# Build OpenHaze.app
#   ./build.sh            build + assemble bundle in build/
#   ./build.sh --install  also copy to ~/Applications
#   ./build.sh --run      also (re)launch the app
set -euo pipefail
cd "$(dirname "$0")"

INSTALL=false
RUN=false
for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=true ;;
    --run) RUN=true ;;
  esac
done

# swiftc is used directly (no SwiftPM needed — plain CLT works, zero dependencies)
echo "▸ Compiling (release)…"
mkdir -p build
swiftc -O \
  -target arm64-apple-macos14.0 \
  -o build/OpenHaze-bin \
  Sources/OpenHaze/*.swift

APP="build/OpenHaze.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp build/OpenHaze-bin "$APP/Contents/MacOS/OpenHaze"
cp Support/Info.plist "$APP/Contents/Info.plist"
cp Support/OpenHaze.sdef "$APP/Contents/Resources/OpenHaze.sdef"

if [ ! -f Support/AppIcon.icns ]; then
  echo "▸ Generating app icon…"
  swift Support/makeicon.swift Support/AppIcon.icns
fi
cp Support/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

echo "▸ Signing (ad-hoc)…"
codesign --force --sign - "$APP"

TARGET="$APP"
if $INSTALL; then
  mkdir -p "$HOME/Applications"
  rm -rf "$HOME/Applications/OpenHaze.app"
  cp -R "$APP" "$HOME/Applications/OpenHaze.app"
  TARGET="$HOME/Applications/OpenHaze.app"
  echo "▸ Installed to $TARGET"
fi

if $RUN; then
  pkill -x OpenHaze 2>/dev/null || true
  sleep 0.5
  open "$TARGET"
  echo "▸ Launched $TARGET"
fi

echo "✓ Done: $TARGET"
