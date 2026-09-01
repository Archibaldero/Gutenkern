#!/bin/sh
set -eu

ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"
PACKAGE="$ROOT/macos/Gutenkern"
DIST="$ROOT/dist"
APP="$DIST/Gutenkern.app"

export MACOSX_DEPLOYMENT_TARGET=13.0

cd "$PACKAGE"
swift run -c debug GutenkernCoreCheck "$ROOT/core/fixtures.json"
swift build -c release --product Gutenkern

BIN="$(swift build -c release --show-bin-path)/Gutenkern"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Gutenkern"
cp "$PACKAGE/Info.plist" "$APP/Contents/Info.plist"
cp "$PACKAGE/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"
cp "$ROOT/core/l10n.json" "$APP/Contents/Resources/l10n.json"
chmod +x "$APP/Contents/MacOS/Gutenkern"
codesign --force --sign - "$APP" >/dev/null

echo "Built $APP"
