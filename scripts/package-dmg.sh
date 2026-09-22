#!/bin/bash
# Builds an ad-hoc signed Snippy.app and a drag-to-Applications disk image.
# Does not replace /Applications/Snippy.app.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DIST="$ROOT/dist"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

SNIPPY_INSTALL=0 SNIPPY_SIGN=adhoc "$ROOT/scripts/build.sh"

mkdir -p "$DIST"
rm -rf "$STAGE/Snippy.app"
cp -R "$ROOT/build/Snippy.app" "$STAGE/Snippy.app"
ln -s /Applications "$STAGE/Applications"

rm -f "$DIST/Snippy.dmg"
hdiutil create \
  -volname "Snippy" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DIST/Snippy.dmg"

echo "Created $DIST/Snippy.dmg"
