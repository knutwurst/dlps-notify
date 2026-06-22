#!/bin/bash
#
# DLPS Notify installer.
# First time: right-click (Control-click) this file and choose "Open".
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

# Quit a running instance, replace the app.
osascript -e 'tell application "DLPSNotify" to quit' >/dev/null 2>&1 || true
rm -rf "$DEST"
cp -R "$SRC" "$DEST"

# Gatekeeper-friendly: strip the quarantine flag so it launches without warnings.
xattr -cr "$DEST" 2>/dev/null || true

# Register with Launch Services and start it.
"$LSREGISTER" -f "$DEST" >/dev/null 2>&1 || true
open "$DEST"

echo
echo "Done — DLPS Notify is now in your menu bar (game-controller icon, top-right)."
echo
echo "If no notifications appear, open System Settings → Notifications and allow"
echo "notifications for \"terminal-notifier\" (DLPS Notify uses it to show banners)."
echo
read -r -p "Press Return to close."
