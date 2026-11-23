#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="MacCaffeine.app"
VERSION="${VERSION:-0.0.0-dev}"
BUILD_NUMBER="${BUILD_NUMBER:-0}"
BIN_DIR="$APP/Contents/MacOS"
RES_DIR="$APP/Contents/Resources"

rm -rf "$APP"
mkdir -p "$BIN_DIR" "$RES_DIR"

echo "Compiling universal binary…"
# Pin the deployment target: swiftc otherwise targets the SDK's OS version, which can be newer
# than the running OS (-10825 "requires conditional 28.0"). Matches LSMinimumSystemVersion below.
for arch in arm64 x86_64; do
  swiftc -O -target "$arch-apple-macosx13.0" main.swift -o "$BIN_DIR/MacCaffeine-$arch"
done
lipo -create "$BIN_DIR"/MacCaffeine-* -output "$BIN_DIR/MacCaffeine"
rm "$BIN_DIR"/MacCaffeine-*
cp assets/AppIcon.icns "$RES_DIR/"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key>            <string>MacCaffeine</string>
  <key>CFBundleDisplayName</key>     <string>MacCaffeine</string>
  <key>CFBundleIdentifier</key>      <string>io.github.rgoomar.maccaffeine</string>
  <key>CFBundleVersion</key>         <string>$BUILD_NUMBER</string>
  <key>CFBundleShortVersionString</key> <string>$VERSION</string>
  <key>CFBundlePackageType</key>     <string>APPL</string>
  <key>CFBundleExecutable</key>      <string>MacCaffeine</string>
  <key>CFBundleIconFile</key>        <string>AppIcon</string>
  <key>NSHumanReadableCopyright</key> <string>© 2026 Rishi Goomar. MIT License.</string>
  <key>LSApplicationCategoryType</key> <string>public.app-category.utilities</string>
  <key>LSUIElement</key>            <true/>
  <key>LSMinimumSystemVersion</key>  <string>13.0</string>
</dict>
</plist>
PLIST

# Ad-hoc sign with hardened runtime + App Sandbox (required for notarization and the Mac App Store).
# release.sh re-signs this with the Developer ID certificate through Xcode.
codesign --force --options runtime --entitlements MacCaffeine.entitlements --sign - "$APP"

echo "Built: $(pwd)/$APP"
