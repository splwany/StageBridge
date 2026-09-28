#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
SDK_PATH="${SDKROOT:-$(xcrun --sdk macosx --show-sdk-path)}"
BUILD_DIR="$ROOT_DIR/.build"
APP="$BUILD_DIR/台前随屏.app"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$BUILD_DIR/ModuleCache"
"$ROOT_DIR/scripts/fetch-sparkle.sh"
SOURCES=(Sources/Core/*.swift Sources/Services/*.swift Sources/App/*.swift)
for ARCH in arm64 x86_64; do
    xcrun swiftc -parse-as-library -O -swift-version 5 -target "$ARCH-apple-macosx14.0" \
        -sdk "$SDK_PATH" -module-cache-path "$BUILD_DIR/ModuleCache" \
        -Xcc "-fmodules-cache-path=$BUILD_DIR/ModuleCache" \
        -F "$BUILD_DIR/Sparkle" -framework Sparkle -Xlinker -rpath -Xlinker @executable_path/../Frameworks \
        "${SOURCES[@]}" -o "$BUILD_DIR/StageByScreen-$ARCH"
done
xcrun lipo -create "$BUILD_DIR/StageByScreen-arm64" "$BUILD_DIR/StageByScreen-x86_64" -output "$APP/Contents/MacOS/StageByScreen"
mkdir -p "$APP/Contents/Frameworks"
/usr/bin/ditto --norsrc "$BUILD_DIR/Sparkle/Sparkle.framework" "$APP/Contents/Frameworks/Sparkle.framework"
cp Resources/Sparkle-LICENSE.txt "$APP/Contents/Resources/"
cp Resources/Info.plist "$APP/Contents/Info.plist"
if [ -f Resources/AppIcon.icns ]; then cp Resources/AppIcon.icns "$APP/Contents/Resources/"; fi
# Remove packaging metadata introduced by synced folders; never change system policy.
xattr -cr "$APP"
if [ -n "${DEVELOPER_ID_APPLICATION:-}" ]; then
    FRAMEWORK="$APP/Contents/Frameworks/Sparkle.framework/Versions/B"
    for COMPONENT in "$FRAMEWORK"/XPCServices/*.xpc "$FRAMEWORK/Updater.app" "$FRAMEWORK/Autoupdate" "$APP/Contents/Frameworks/Sparkle.framework"; do
        codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$COMPONENT"
    done
    codesign --force --options runtime --timestamp --sign "$DEVELOPER_ID_APPLICATION" "$APP"
else
    codesign --force --sign - "$APP"
fi
codesign --verify --strict "$APP"
printf 'Built %s\n' "$APP"
