#!/bin/bash
# Adapted from the macos-spm-app-packaging skill's package_app.sh template.
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/.." && pwd)
CONF=${1:-release}
export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-$ROOT/.build/clang-cache}"
export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-$ROOT/.build/swift-cache}"
swift build --package-path "$ROOT" -c "$CONF" --disable-sandbox
BIN=$(swift build --package-path "$ROOT" -c "$CONF" --show-bin-path)
APP="$ROOT/build/Razes.app"
# Only replace this script's generated app bundle.
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN/RazesMac" "$APP/Contents/MacOS/RazesMac"
for resource in Razes_RazesCore.bundle Razes_RazesMac.bundle; do
    cp -R "$BIN/$resource" "$APP/Contents/Resources/"
done
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>CFBundleName</key><string>Răzeș</string>
<key>CFBundleDisplayName</key><string>Răzeș</string>
<key>CFBundleIdentifier</key><string>com.razes.game</string>
<key>CFBundleExecutable</key><string>RazesMac</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>0.1.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>14.0</string>
<key>NSHighResolutionCapable</key><true/>
</dict></plist>
PLIST
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
test -x "$APP/Contents/MacOS/RazesMac"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Contents/Info.plist")" = com.razes.game
test "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$APP/Contents/Info.plist")" = 14.0
test -f "$APP/Contents/Resources/Razes_RazesCore.bundle/Contents/Resources/content.json" || test -f "$APP/Contents/Resources/Razes_RazesCore.bundle/content.json"
test -f "$APP/Contents/Resources/Razes_RazesMac.bundle/Contents/Resources/Resources/Art/spring.png" || test -f "$APP/Contents/Resources/Razes_RazesMac.bundle/Resources/Art/spring.png"
for art in settlement-rear-v2 settlement-rear-winter settlement-buildings settlement-buildings-winter terrain-grass terrain-earth terrain-snow woodshed-construction woodshed-complete woodshed-winter cellar-construction cellar-complete cellar-winter; do
    test -f "$APP/Contents/Resources/Razes_RazesMac.bundle/Contents/Resources/Resources/Art/$art.png" || test -f "$APP/Contents/Resources/Razes_RazesMac.bundle/Resources/Art/$art.png"
done
codesign --verify --deep --strict "$APP"
echo "$APP"
