#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PRODUCT="Sift"
BUNDLE_ID="${BUNDLE_ID:-ai.cyclones.sift}"
BUILD_DIR="$ROOT/.build/arm64-apple-macosx/release"
APP_DIR="$ROOT/.build/distribution/Sift.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Building $PRODUCT (release)…"
swift build -c release --product Sift

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

cp "$BUILD_DIR/Sift" "$MACOS/Sift"
chmod +x "$MACOS/Sift"

cp "$ROOT/Sources/SiftApp/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Sources/SiftApp/PrivacyInfo.xcprivacy" "$RESOURCES/PrivacyInfo.xcprivacy" 2>/dev/null || true

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$CONTENTS/Info.plist" 2>/dev/null || true

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --deep --options runtime \
    --entitlements "$ROOT/Packaging/Entitlements/Sift.entitlements" \
    --sign "$SIGN_IDENTITY" \
    "$APP_DIR"
  echo "Signed with $SIGN_IDENTITY"
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$CONTENTS/Info.plist")"
STAGE="$ROOT/.build/distribution/dmg-stage"
DMG="$ROOT/.build/distribution/Sift.dmg"

rm -rf "$STAGE"
mkdir -p "$STAGE"
cp -R "$APP_DIR" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create \
  -volname "Sift ${VERSION}" \
  -srcfolder "$STAGE" \
  -ov \
  -format UDZO \
  "$DMG"

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$DMG"
fi

echo "Built: $APP_DIR"
echo "DMG:   $DMG"
