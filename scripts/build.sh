#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
SDK_PATH="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"
BUILD_DIR="$ROOT_DIR/.build"
APP="$BUILD_DIR/StageBridge.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD_DIR/ModuleCache"
SOURCES=(Sources/Core/*.swift Sources/App/*.swift)
for ARCH in arm64 x86_64; do
    xcrun swiftc -parse-as-library -O -swift-version 5 -target "$ARCH-apple-macosx14.0" \
        -sdk "$SDK_PATH" -module-cache-path "$BUILD_DIR/ModuleCache" \
        -Xcc "-fmodules-cache-path=$BUILD_DIR/ModuleCache" \
        "${SOURCES[@]}" -o "$BUILD_DIR/StageBridge-$ARCH"
done
xcrun lipo -create "$BUILD_DIR/StageBridge-arm64" "$BUILD_DIR/StageBridge-x86_64" -output "$APP/Contents/MacOS/StageBridge"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/"; fi
# Remove packaging metadata introduced by synced folders; never change system policy.
xattr -cr "$APP"
if [ -n "${DEVELOPER_ID_APPLICATION:-}" ]; then
    codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$APP"
else
    codesign --force --sign - "$APP"
fi
codesign --verify --strict "$APP"
printf 'Built %s\n' "$APP"
