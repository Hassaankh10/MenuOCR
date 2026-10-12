#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
APP="$PWD/dist/MenuOCR.app"
if [[ ! -d "$APP" ]]; then
    echo "Run ./build.sh first." >&2
    exit 1
fi
VERSION=$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")
mkdir -p .build
STAGE=$(mktemp -d "$PWD/.build/dmg.XXXXXX")
trap 'rm -rf "$STAGE"' EXIT
ditto "$APP" "$STAGE/MenuOCR.app"
ln -s /Applications "$STAGE/Applications"
cp Assets/Installer.DS_Store "$STAGE/.DS_Store"
hdiutil create -volname "MenuOCR — Drag to Applications" -srcfolder "$STAGE" -format UDZO -fs HFS+ -ov "dist/MenuOCR-${VERSION}-macOS-arm64.dmg"
hdiutil verify "dist/MenuOCR-${VERSION}-macOS-arm64.dmg"
