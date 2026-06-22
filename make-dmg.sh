#!/usr/bin/env bash
#
# Package DLPSNotify.app into a distributable .dmg with a gatekeeper-friendly
# installer. Run ./build.sh first.
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
APP="$ROOT/DLPSNotify.app"

[ -d "$APP" ] || { echo "DLPSNotify.app not found — run ./build.sh first."; exit 1; }

VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$ROOT/DLPSNotify-$VERSION.dmg"
STAGE="$(mktemp -d)/DLPS Notify"
mkdir -p "$STAGE"

cp -R "$APP" "$STAGE/DLPSNotify.app"
cp "$ROOT/dist/Install.command" "$STAGE/Install.command"
chmod +x "$STAGE/Install.command"
cp "$ROOT/dist/READ-ME-FIRST.txt" "$STAGE/READ ME FIRST.txt"

rm -f "$DMG"
hdiutil create -volname "DLPS Notify" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$(dirname "$STAGE")"

echo "✅ $DMG"
