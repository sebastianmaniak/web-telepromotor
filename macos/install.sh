#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
MACOS="$ROOT/macos"
APP_NAME="Teleprompter Overlay.app"
DEST="${HOME}/Applications/${APP_NAME}"

cd "$MACOS"
swift build -c release --product TeleprompterOverlay
BIN="$(swift build -c release --show-bin-path)/TeleprompterOverlay"

mkdir -p "${HOME}/Applications"
rm -rf "$DEST"
mkdir -p "$DEST/Contents/MacOS" "$DEST/Contents/Resources/scripts"

cp "$BIN" "$DEST/Contents/MacOS/TeleprompterOverlay"
cp "$MACOS/Info.plist" "$DEST/Contents/Info.plist"
cp "$ROOT/scripts/"*.md "$DEST/Contents/Resources/scripts/"

# Ad-hoc sign so macOS will launch it
codesign --force --sign - "$DEST/Contents/MacOS/TeleprompterOverlay" >/dev/null
codesign --force --sign - "$DEST" >/dev/null

echo "Installed: $DEST"
