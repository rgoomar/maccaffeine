#!/bin/bash
# Publishes a release: build → Developer ID sign + notarize (through your Xcode account) →
# GitHub release → Homebrew cask update.
# Needs: Xcode signed in to a paid Apple Developer team (Admin or Account Holder), and `gh` signed in.
# Usage: ./release.sh 1.1.0
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:?usage: ./release.sh <version>}"
TAG="v$VERSION"
TEAM_ID="${TEAM_ID:?set TEAM_ID to your Apple Developer team ID}"
BUNDLE_ID="io.github.rgoomar.maccaffeine"

[ -z "$(git status --porcelain)" ] || { echo "Commit your changes first."; exit 1; }
git fetch -q origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "Push main first."; exit 1; }

BUILD_NUMBER="$(git rev-list --count HEAD)"
VERSION="$VERSION" BUILD_NUMBER="$BUILD_NUMBER" ./build.sh

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT

# xcodebuild only exports archives, so wrap the built app in a minimal .xcarchive.
ARCHIVE="$W/MacCaffeine.xcarchive"
mkdir -p "$ARCHIVE/Products/Applications"
cp -R MacCaffeine.app "$ARCHIVE/Products/Applications/"
cat > "$ARCHIVE/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>ApplicationProperties</key>
  <dict>
    <key>ApplicationPath</key>            <string>Applications/MacCaffeine.app</string>
    <key>CFBundleIdentifier</key>         <string>$BUNDLE_ID</string>
    <key>CFBundleShortVersionString</key> <string>$VERSION</string>
    <key>CFBundleVersion</key>            <string>$BUILD_NUMBER</string>
  </dict>
  <key>ArchiveVersion</key> <integer>2</integer>
  <key>CreationDate</key>   <date>$(date -u +%Y-%m-%dT%H:%M:%SZ)</date>
  <key>Name</key>           <string>MacCaffeine</string>
  <key>SchemeName</key>     <string>MacCaffeine</string>
</dict>
</plist>
PLIST

cat > "$W/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>method</key>      <string>developer-id</string>
  <key>signingStyle</key> <string>automatic</string>
  <key>teamID</key>      <string>$TEAM_ID</string>
  <key>destination</key> <string>upload</string>
</dict>
</plist>
PLIST

echo "Signing and uploading for notarization…"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist "$W/ExportOptions.plist" \
  -exportPath "$W/upload" -allowProvisioningUpdates -quiet

echo "Waiting for notarization…"
until xcodebuild -exportNotarizedApp -archivePath "$ARCHIVE" -exportPath "$W/final" >"$W/notary.log" 2>&1; do
  grep -q "is processing" "$W/notary.log" || { cat "$W/notary.log"; exit 1; }
  sleep 15
done

APP="$W/final/MacCaffeine.app"
xcrun stapler validate "$APP"
spctl --assess --type execute -vv "$APP"
ditto -c -k --keepParent "$APP" "$W/MacCaffeine.zip"
SHA256="$(shasum -a 256 "$W/MacCaffeine.zip" | cut -d' ' -f1)"

echo "Publishing $TAG…"
git tag "$TAG"
git push -q origin "$TAG"
gh release create "$TAG" "$W/MacCaffeine.zip" --generate-notes

echo "Updating Homebrew cask…"
gh repo clone rgoomar/homebrew-tap "$W/tap" -- -q
mkdir -p "$W/tap/Casks"
cat > "$W/tap/Casks/maccaffeine.rb" <<CASK
cask "maccaffeine" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/rgoomar/maccaffeine/releases/download/v#{version}/MacCaffeine.zip"
  name "MacCaffeine"
  desc "Menu bar app that keeps your Mac awake"
  homepage "https://github.com/rgoomar/maccaffeine"

  depends_on macos: ">= :ventura"

  app "MacCaffeine.app"

  uninstall quit: "$BUNDLE_ID"

  zap trash: "~/Library/Containers/$BUNDLE_ID"
end
CASK
git -C "$W/tap" add Casks/maccaffeine.rb
git -C "$W/tap" commit -qm "maccaffeine $VERSION"
git -C "$W/tap" push -q

echo "Released $TAG: https://github.com/rgoomar/maccaffeine/releases/tag/$TAG"
