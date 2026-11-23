#!/bin/bash
# Installs the latest MacCaffeine release into /Applications and starts it.
# curl does not add the quarantine flag, so Gatekeeper does not block the unsigned app.
set -euo pipefail

URL="https://github.com/rgoomar/maccaffeine/releases/latest/download/MacCaffeine.zip"
DEST="/Applications"
[ -w "$DEST" ] || DEST="$HOME/Applications"
mkdir -p "$DEST"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "Downloading MacCaffeine…"
curl -fsSL "$URL" -o "$TMP/MacCaffeine.zip"
ditto -x -k "$TMP/MacCaffeine.zip" "$TMP"

pkill -x MacCaffeine || true
rm -rf "$DEST/MacCaffeine.app"
mv "$TMP/MacCaffeine.app" "$DEST/"

open "$DEST/MacCaffeine.app"
echo "Installed to $DEST/MacCaffeine.app. Look for the cup in your menu bar."
