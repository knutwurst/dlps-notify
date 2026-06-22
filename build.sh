#!/usr/bin/env bash
#
# Build DLPSNotify and assemble a runnable, self-contained, ad-hoc-signed .app.
# Bundles terminal-notifier so the app needs no Homebrew at runtime.
# Usage: ./build.sh [debug|release]   (default: release)
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
CONFIG="${1:-release}"
APP="$ROOT/DLPSNotify.app"

echo "▶ swift build ($CONFIG) …"
swift build -c "$CONFIG"
BIN="$(swift build -c "$CONFIG" --show-bin-path)/DLPSNotify"

echo "▶ assembling $APP …"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/DLPSNotify"
cp "$ROOT/Resources/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/Resources/appicon.png" "$APP/Contents/Resources/appicon.png"

# Bundle terminal-notifier (self-contained: no Homebrew needed on the target Mac).
TN_APP=""
if command -v brew >/dev/null 2>&1; then
  CANDIDATE="$(brew --prefix terminal-notifier 2>/dev/null)/terminal-notifier.app"
  [ -d "$CANDIDATE" ] && TN_APP="$CANDIDATE"
fi
if [ -n "$TN_APP" ]; then
  cp -R "$TN_APP" "$APP/Contents/Resources/terminal-notifier.app"
  echo "▶ bundled terminal-notifier from $TN_APP"
else
  echo "⚠️  terminal-notifier.app not found to bundle — install with 'brew install terminal-notifier'."
fi

echo "▶ ad-hoc code signing (outer app only; bundled helper keeps its signature) …"
codesign --force --sign - "$APP"
codesign --verify --verbose "$APP" || true

echo "✅ built $APP"
