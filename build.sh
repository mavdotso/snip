#!/bin/sh
set -e
cd "$(dirname "$0")"
APP=build/snip.app
ID="${SIGNING_IDENTITY:-$(security find-identity -v -p codesigning | awk '/Apple Development/ { print $2; exit }')}"
if [ "${1:-}" = "--install" ] && { [ -z "$ID" ] || [ "$ID" = "-" ]; }; then
    echo "Cannot install without a signing identity: ad-hoc rebuilds invalidate Screen Recording permission." >&2
    echo "Run with access to your login keychain, or set SIGNING_IDENTITY to your code-signing identity." >&2
    exit 1
fi
VERSION="${VERSION:-$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')}"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
swiftc -O -target arm64-apple-macosx14.0 main.swift -o "$APP/Contents/MacOS/snip"
cp icon.svg AppIcon.icns "$APP/Contents/Resources/"
cp -R assets/hugeicons "$APP/Contents/Resources/hugeicons"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleExecutable</key><string>snip</string>
<key>CFBundleIconFile</key><string>AppIcon</string>
<key>CFBundleIdentifier</key><string>so.mav.snip</string>
<key>CFBundleName</key><string>snip</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>${VERSION:-0.0.0-dev}</string>
<key>CFBundleVersion</key><string>$(git rev-list --count HEAD 2>/dev/null || echo 1)</string>
<key>LSUIElement</key><true/>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
codesign -f --options runtime -s "${ID:--}" "$APP"
codesign --verify --deep --strict "$APP"
echo "built $APP, signed '${ID:-ad-hoc}'"
if [ "${1:-}" = "--install" ]; then
    osascript -e 'if application "snip" is running then tell application "snip" to quit'
    ditto "$APP" /Applications/snip.app
    codesign --verify --deep --strict /Applications/snip.app
    open /Applications/snip.app
    echo "installed /Applications/snip.app"
fi
