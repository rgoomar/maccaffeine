#!/bin/bash
# Publishes a release: build → Developer ID sign → notarize + staple the app → signed DMG →
# notarize + staple the DMG → GitHub release → Homebrew cask update.
# Needs in the login keychain:
#   - the "Developer ID Application" certificate and private key
#   - notary credentials: xcrun notarytool store-credentials maccaffeine-notary --key … --key-id … --issuer …
# and `gh` signed in.
# Usage: ./release.sh 1.2.0
set -euo pipefail
cd "$(dirname "$0")"

VERSION="${1:?usage: ./release.sh <version>}"
TAG="v$VERSION"
IDENTITY="Developer ID Application"
NOTARY_PROFILE="maccaffeine-notary"
BUNDLE_ID="io.github.rgoomar.maccaffeine"

[ -z "$(git status --porcelain)" ] || { echo "Commit your changes first."; exit 1; }
git fetch -q origin main
[ "$(git rev-parse HEAD)" = "$(git rev-parse origin/main)" ] || { echo "Push main first."; exit 1; }

W="$(mktemp -d)"
trap 'rm -rf "$W"' EXIT

notarize() {
  xcrun notarytool submit "$1" --keychain-profile "$NOTARY_PROFILE" --wait --output-format json > "$W/notary.json" || true
  if ! grep -Eq '"status" *: *"Accepted"' "$W/notary.json"; then
    cat "$W/notary.json"
    id="$(sed -nE 's/.*"id" *: *"([^"]*)".*/\1/p' "$W/notary.json")"
    [ -z "$id" ] || xcrun notarytool log "$id" --keychain-profile "$NOTARY_PROFILE"
    exit 1
  fi
}

VERSION="$VERSION" BUILD_NUMBER="$(git rev-list --count HEAD)" SIGN_IDENTITY="$IDENTITY" ./build.sh

echo "Notarizing the app…"
ditto -c -k --keepParent MacCaffeine.app "$W/app.zip"
notarize "$W/app.zip"
xcrun stapler staple MacCaffeine.app

echo "Building the DMG…"
mkdir "$W/dmg"
cp -R MacCaffeine.app "$W/dmg/"
ln -s /Applications "$W/dmg/Applications"
DMG="$W/MacCaffeine.dmg"
hdiutil create -quiet -volname MacCaffeine -srcfolder "$W/dmg" -format UDZO "$DMG"
codesign --sign "$IDENTITY" --timestamp "$DMG"

echo "Notarizing the DMG…"
notarize "$DMG"
xcrun stapler staple "$DMG"
spctl --assess --type open --context context:primary-signature -vv "$DMG"
SHA256="$(shasum -a 256 "$DMG" | cut -d' ' -f1)"

echo "Publishing ${TAG}…"
git tag "$TAG"
git push -q origin "$TAG"
gh release create "$TAG" "$DMG" --generate-notes

echo "Updating Homebrew cask…"
gh repo clone rgoomar/homebrew-tap "$W/tap" -- -q
mkdir -p "$W/tap/Casks"
cat > "$W/tap/Casks/maccaffeine.rb" <<CASK
cask "maccaffeine" do
  version "$VERSION"
  sha256 "$SHA256"

  url "https://github.com/rgoomar/maccaffeine/releases/download/v#{version}/MacCaffeine.dmg"
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
