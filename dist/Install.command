#!/bin/bash
#
# first run: right click -> Open
#
set -e

HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/DLPSNotify.app"
DEST="/Applications/DLPSNotify.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

echo "Installing DLPS Notify…"

if [ ! -d "$SRC" ]; then
    echo "Error: DLPSNotify.app not found next to this script."
    read -r -p "Press Return to close."
    exit 1
fi

osascript -e 'tell application "DLPSNotify" to quit' >/dev/null 2>&1 || true
rm -rf "$DEST"
cp -R "$SRC" "$DEST"

# no quarantine flag = no Gatekeeper nagging
xattr -cr "$DEST" 2>/dev/null || true

"$LSREGISTER" -f "$DEST" >/dev/null 2>&1 || true
open "$DEST"

echo
echo "Done — DLPS Notify is now in your menu bar (game-controller icon, top-right)."
echo
echo "If no notifications appear, open System Settings → Notifications and allow"
echo "notifications for \"terminal-notifier\" (DLPS Notify uses it to show banners)."
echo
read -r -p "Press Return to close."
