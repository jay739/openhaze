#!/bin/bash
# Package build/OpenHaze.app into the drag-to-install disk image.
#   ./package-dmg.sh 0.2.1    writes OpenHaze-0.2.1-macOS.dmg
# The version only names the file. Releases stamp the app's own version into
# Info.plist from the tag before building. Run ./build.sh first.
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:-}"
if [ -z "$VERSION" ]; then
  echo "Usage: ./package-dmg.sh VERSION   (for example ./package-dmg.sh 0.2.1)" >&2
  exit 1
fi
if [ ! -d build/OpenHaze.app ]; then
  echo "build/OpenHaze.app not found. Run ./build.sh first." >&2
  exit 1
fi
# dmgbuild needs Python 3.10 or newer; the Command Line Tools ship 3.9.
if ! python3 -c 'import sys; sys.exit(sys.version_info < (3, 10))' 2>/dev/null; then
  echo "package-dmg.sh needs Python 3.10 or newer for dmgbuild, found: $(python3 --version 2>&1)" >&2
  echo "Install one with: brew install python" >&2
  exit 1
fi

echo "▸ Drawing the window background…"
swiftc -module-cache-path build/module-cache -o build/makedmgbackground Support/makedmgbackground.swift
build/makedmgbackground build/dmg-background.png

# dmgbuild writes the Finder layout (window size, icon positions, background)
# straight into the image's .DS_Store, so it never has to script Finder, which
# can stall on CI. It runs from a venv under build/ that is recreated each time,
# so a moved checkout or an upgraded Python cannot leave it broken, and the
# system Python is never touched. Its dependencies are pinned too, so release
# images do not change when a new version appears on PyPI.
echo "▸ Installing dmgbuild…"
python3 -m venv --clear build/dmgenv
build/dmgenv/bin/python -m pip install --quiet --disable-pip-version-check \
  dmgbuild==1.6.7 ds_store==1.3.3 mac_alias==2.2.3

DMG="OpenHaze-$VERSION-macOS.dmg"
echo "▸ Packaging ${DMG}…"
rm -f "$DMG"
build/dmgenv/bin/python -m dmgbuild -s dmg-settings.py "OpenHaze" "$DMG"

echo "✓ Done: $DMG"
