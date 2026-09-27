#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
APP="$ROOT_DIR/.build/StageBridge.app"
[ -d "$APP" ] || { printf 'Run scripts/build.sh first.\n' >&2; exit 1; }
source "$ROOT_DIR/scripts/version.sh"
mkdir -p dist
STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/stagebridge-dmg.XXXXXX")"
trap 'rm -rf "$STAGE_DIR"' EXIT
/usr/bin/ditto --norsrc "$APP" "$STAGE_DIR/StageBridge.app"
xattr -cr "$STAGE_DIR/StageBridge.app"
codesign --verify --strict "$STAGE_DIR/StageBridge.app"
ln -s /Applications "$STAGE_DIR/Applications"
cp docs/INSTALL.md "$STAGE_DIR/使用说明.md"
cp LICENSE "$STAGE_DIR/LICENSE.txt"
mkdir -p "$STAGE_DIR/docs"
cp docs/PRIVACY.md docs/DISTRIBUTION.md "$STAGE_DIR/docs/"
hdiutil create -ov -format UDZO -volname "StageBridge $VERSION" -srcfolder "$STAGE_DIR" "dist/StageBridge-$VERSION-universal.dmg"
shasum -a 256 "dist/StageBridge-$VERSION-universal.dmg" > dist/SHA256SUMS.txt
