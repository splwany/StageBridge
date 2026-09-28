#!/bin/bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
VERSION=2.10.0
CHECKSUM=c2bf58aa8387266ac179357b1415d6f2635f044da8be41042af32425dae6da0c
DEST="$ROOT_DIR/.build/Sparkle"
ARCHIVE="$ROOT_DIR/.build/Sparkle-$VERSION.tar.xz"
mkdir -p "$ROOT_DIR/.build"
if [ ! -f "$ARCHIVE" ]; then
  curl --fail --location --retry 3 --silent --show-error \
    "https://github.com/sparkle-project/Sparkle/releases/download/$VERSION/Sparkle-$VERSION.tar.xz" -o "$ARCHIVE.tmp"
  mv "$ARCHIVE.tmp" "$ARCHIVE"
fi
ACTUAL=$(shasum -a 256 "$ARCHIVE" | awk '{print $1}')
[ "$ACTUAL" = "$CHECKSUM" ] || { echo 'Sparkle checksum mismatch' >&2; exit 1; }
if [ ! -f "$DEST/.verified-$CHECKSUM" ]; then
  mkdir -p "$DEST"
  tar -xJf "$ARCHIVE" -C "$DEST"
  touch "$DEST/.verified-$CHECKSUM"
fi
