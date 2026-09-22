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
  -framework Carbon \
  -framework UniformTypeIdentifiers \
  -framework UserNotifications \
  "${SOURCES[@]}"

cp "$ROOT/packaging/Info.plist" "$APP/Contents/Info.plist"
printf 'APPL????' > "$APP/Contents/PkgInfo"
mkdir -p "$RESOURCES/de.lproj" "$RESOURCES/en.lproj"
cp "$ROOT/Snippy/de.lproj/"* "$RESOURCES/de.lproj/"
cp "$ROOT/Snippy/en.lproj/"* "$RESOURCES/en.lproj/"
cp "$ROOT/Snippy/MenuIcon.png" "$RESOURCES/MenuIcon.png"
iconutil -c icns "$ROOT/Snippy/AppIcon.iconset" -o "$RESOURCES/AppIcon.icns"

# SNIPPY_SIGN=auto | development | adhoc
# auto uses the local Apple Development identity when it is installed.
# adhoc is for the public DMG: it is not tied to this Mac's developer certificate.
SIGN_MODE="${SNIPPY_SIGN:-auto}"
codesign_app() {
  local target="$1"
  local dev_id="Apple Development: nuernberger99@aol.com (R2L8FM9VJ7)"
  local identity="-"
  if [[ "$SIGN_MODE" != "adhoc" ]] && security find-identity -p codesigning -v 2>/dev/null | grep -F -q "$dev_id"; then
    identity="$dev_id"
  fi
  if [[ "$identity" == "-" ]]; then
    codesign --force --sign - --entitlements "$ROOT/Snippy/Snippy.entitlements" "$target"
  else
    codesign --force --sign "$identity" --options runtime --entitlements "$ROOT/Snippy/Snippy.entitlements" "$target"
  fi
}

codesign_app "$APP"

if [[ "${SNIPPY_INSTALL:-1}" == "1" ]]; then
  installed="/Applications/Snippy.app"
  if rm -rf "$installed" && cp -R "$APP" "$installed"; then
    codesign_app "$installed"
    rm -rf "$APP"
    echo "Installed $installed"
  else
    echo "Built $APP"
  fi
else
  echo "Built $APP"
fi
