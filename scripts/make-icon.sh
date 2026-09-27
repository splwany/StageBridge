#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
SDK_PATH="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"
mkdir -p .build/ModuleCache
xcrun swiftc -sdk "$SDK_PATH" -module-cache-path "$ROOT_DIR/.build/ModuleCache" \
    scripts/make-icon.swift -o .build/make-icon
.build/make-icon
iconutil --convert icns --output Resources/AppIcon.icns .build/AppIcon.iconset
printf 'Generated Resources/AppIcon.icns\n'
