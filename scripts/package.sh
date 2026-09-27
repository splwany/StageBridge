#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"
APP="$ROOT_DIR/.build/StageBridge.app"
[ -d "$APP" ] || { printf 'Run scripts/build.sh first.\n' >&2; exit 1; }
mkdir -p dist
STAGE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/stagebridge-dmg.XXXXXX")"
trap 'rm -rf "$STAGE_DIR"' EXIT
/usr/bin/ditto --norsrc "$APP" "$STAGE_DIR/StageBridge.app"
xattr -cr "$STAGE_DIR/StageBridge.app"
codesign --verify --strict "$STAGE_DIR/StageBridge.app"
ln -s /Applications "$STAGE_DIR/Applications"
cp README.md "$STAGE_DIR/使用说明.md"
cp LICENSE "$STAGE_DIR/LICENSE.txt"
/usr/bin/ditto --norsrc docs "$STAGE_DIR/docs"
hdiutil create -ov -format UDZO -volname 'StageBridge 0.1.0 beta 1' -srcfolder "$STAGE_DIR" dist/StageBridge-0.1.0-beta.1-universal.dmg
shasum -a 256 dist/StageBridge-0.1.0-beta.1-universal.dmg > dist/SHA256SUMS.txt
