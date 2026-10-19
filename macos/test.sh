#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build
swiftc -module-cache-path build/test-module-cache -o build/fullscreen-tests Sources/OpenHaze/WindowSnapshot.swift Sources/OpenHaze/FullscreenDetection.swift Sources/OpenHaze/OverlayWindow.swift Sources/OpenHaze/Settings.swift Sources/OpenHaze/FocusTracker.swift Sources/OpenHaze/HazeEngine.swift Tests/main.swift
build/fullscreen-tests
