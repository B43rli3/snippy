#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SWIFTC="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/swiftc"
SDK="/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk"
APP="$ROOT/build/Snippy.app"
MACOS="$APP/Contents/MacOS"
RESOURCES="$APP/Contents/Resources"

if [[ ! -x "$SWIFTC" ]]; then
  echo "swiftc not found at $SWIFTC" >&2
  exit 1
fi

rm -rf "$APP"
mkdir -p "$MACOS" "$RESOURCES"

SOURCES=()
while IFS= read -r file; do
  SOURCES+=("$file")
done < <(find "$ROOT/Snippy" -name '*.swift' | sort)

"$SWIFTC" \
  -sdk "$SDK" \
  -target arm64-apple-macos15.2 \
  -swift-version 5 \
  -parse-as-library \
  -O \
  -o "$MACOS/Snippy" \
  -framework AppKit \
  -framework SwiftUI \
  -framework ScreenCaptureKit \
  -framework ServiceManagement \
  -framework ApplicationServices \
  -framework Combine \
  -framework CoreGraphics \
  -framework ImageIO \
  -framework UniformTypeIdentifiers \
  "${SOURCES[@]}"

cp "$ROOT/packaging/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
mkdir -p "$RESOURCES/de.lproj" "$RESOURCES/en.lproj"
cp "$ROOT/Snippy/de.lproj/"* "$RESOURCES/de.lproj/"
cp "$ROOT/Snippy/en.lproj/"* "$RESOURCES/en.lproj/"

codesign --force --sign - --entitlements "$ROOT/Snippy/Snippy.entitlements" "$APP" >/dev/null

echo "Built $APP"
