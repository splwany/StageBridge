#!/bin/bash
# Sourced by release scripts after APP has been selected.
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :StageByScreenReleaseVersion' "$APP/Contents/Info.plist")
if [[ ! "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-z]+\.[0-9]+)?$ ]]; then
    printf 'Invalid release version in app bundle: %s\n' "$VERSION" >&2
    exit 1
fi
SOURCE_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :StageByScreenReleaseVersion' "$ROOT_DIR/Resources/Info.plist")
if [ "$VERSION" != "$SOURCE_VERSION" ]; then
    printf 'App version differs from source. Rebuild before packaging.\n' >&2
    exit 1
fi
