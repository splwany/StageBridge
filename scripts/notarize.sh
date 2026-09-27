#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to a notarytool Keychain profile}"
: "${DEVELOPER_ID_APPLICATION:?Build with your Developer ID Application identity first}"
APP="$ROOT_DIR/.build/StageBridge.app"
codesign --verify --strict "$APP"
codesign -dv "$APP" 2>&1 | grep -q 'Authority=Developer ID Application:' || { printf 'Developer ID signature required.\n' >&2; exit 1; }
ditto -c -k --keepParent "$APP" .build/StageBridge-notary.zip
xcrun notarytool submit .build/StageBridge-notary.zip --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$APP"
./scripts/package.sh
DMG=dist/StageBridge-0.1.0-beta.1-universal.dmg
codesign --sign "$DEVELOPER_ID_APPLICATION" --timestamp "$DMG"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait
xcrun stapler staple "$DMG"
shasum -a 256 "$DMG" > dist/SHA256SUMS.txt
