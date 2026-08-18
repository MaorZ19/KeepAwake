#!/bin/bash
# Build KeepAwake.app and install it.
# The Control Center widget extension is built only when the macOS 26+ SDK
# is available (xcode-select --install on macOS 26 gets you there).
set -euo pipefail
cd "$(dirname "$0")"

APP_NAME="KeepAwake"
EXT_NAME="KeepAwakeControl"

if [ -w /Applications ]; then INSTALL_DIR="/Applications"; else INSTALL_DIR="$HOME/Applications"; fi
APP="$INSTALL_DIR/$APP_NAME.app"

SDK_MAJOR=$(xcrun --show-sdk-version | cut -d. -f1)
BUNDLE="build/$APP_NAME.app"
APPEX="$BUNDLE/Contents/PlugIns/$EXT_NAME.appex"

mkdir -p build
rm -rf "$BUNDLE"
mkdir -p "$BUNDLE/Contents/MacOS"
cp Info.plist "$BUNDLE/Contents/"

if [ "$SDK_MAJOR" -ge 26 ]; then
	swiftc -O main.swift shared.swift -o "$BUNDLE/Contents/MacOS/$APP_NAME"
	swiftc -O -parse-as-library control.swift shared.swift -o "build/$EXT_NAME"
	mkdir -p "$APPEX/Contents/MacOS"
	cp control-Info.plist "$APPEX/Contents/Info.plist"
	cp "build/$EXT_NAME" "$APPEX/Contents/MacOS/"
	codesign --force --sign - --entitlements control.entitlements "$APPEX"
else
	echo "SDK $SDK_MAJOR < 26 — building without the Control Center extension"
	swiftc -O -D NO_CONTROL_CENTER main.swift shared.swift -o "$BUNDLE/Contents/MacOS/$APP_NAME"
fi

# App icon (regenerate docs/logo.png from the SVG source with:
#   qlmanage -t -s 1024 -o docs docs/logo.svg && mv docs/logo.svg.png docs/logo.png)
if [ -f docs/logo.png ]; then
	ICONSET="build/AppIcon.iconset"
	rm -rf "$ICONSET"; mkdir -p "$ICONSET"
	for s in 16 32 128 256 512; do
		sips -z $s $s docs/logo.png --out "$ICONSET/icon_${s}x${s}.png" >/dev/null
		sips -z $((s*2)) $((s*2)) docs/logo.png --out "$ICONSET/icon_${s}x${s}@2x.png" >/dev/null
	done
	iconutil -c icns "$ICONSET" -o "build/AppIcon.icns"
	mkdir -p "$BUNDLE/Contents/Resources"
	cp build/AppIcon.icns "$BUNDLE/Contents/Resources/"
fi

codesign --force --sign - "$BUNDLE"

mkdir -p "$INSTALL_DIR"
pkill -x "$APP_NAME" 2>/dev/null || true
rm -rf "$APP"
cp -R "$BUNDLE" "$APP"

# Make LaunchServices/PlugInKit notice the app (and extension, if built).
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APP"
[ -d "$APP/Contents/PlugIns/$EXT_NAME.appex" ] && pluginkit -a "$APP/Contents/PlugIns/$EXT_NAME.appex" 2>/dev/null || true

echo "Installed: $APP"
