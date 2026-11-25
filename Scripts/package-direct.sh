#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

PRODUCT="Sift"
BUNDLE_ID="${BUNDLE_ID:-ai.cyclones.sift}"
BUILD_DIR="$ROOT/.build/arm64-apple-macosx/release"
# Set DIST_DIR outside iCloud Drive when the checkout lives in Documents or Desktop:
# iCloud keeps adding attributes that codesign refuses. Example: DIST_DIR=~/Library/Caches/sift-dist
DIST_DIR="${DIST_DIR:-$ROOT/.build/distribution}"
APP_DIR="$DIST_DIR/Sift.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

echo "Building $PRODUCT (release)…"
if [[ "${SKIP_SWIFT_BUILD:-}" != 1 ]]; then
  swift build -c release --product Sift
fi

rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"

cp "$BUILD_DIR/Sift" "$MACOS/Sift"
chmod +x "$MACOS/Sift"

# The binary loads Sparkle from @loader_path, next to the executable.
cp -R "$BUILD_DIR/Sparkle.framework" "$MACOS/Sparkle.framework"

cp "$ROOT/Sources/SiftApp/Info.plist" "$CONTENTS/Info.plist"
cp "$ROOT/Sources/SiftApp/PrivacyInfo.xcprivacy" "$RESOURCES/PrivacyInfo.xcprivacy" 2>/dev/null || true

# Inside Contents/Resources. The app root cannot hold extra bundles; codesign rejects them.
# Bundle.module still looks beside the .app, so the app resolves these bundles itself.
for bundle in "$BUILD_DIR"/*.bundle; do
  name="$(basename "$bundle" .bundle)"
  dest="$RESOURCES/$name.bundle"
  cp -R "$bundle" "$dest"
  if [[ ! -f "$dest/Info.plist" ]]; then
    /usr/libexec/PlistBuddy -c "Add :CFBundleDevelopmentRegion string en" "$dest/Info.plist"
  fi
  /usr/libexec/PlistBuddy -c "Add :CFBundlePackageType string BNDL" "$dest/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :CFBundlePackageType BNDL" "$dest/Info.plist"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIdentifier string ${BUNDLE_ID}.resources.${name}" "$dest/Info.plist" 2>/dev/null \
    || /usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier ${BUNDLE_ID}.resources.${name}" "$dest/Info.plist"
done

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier $BUNDLE_ID" "$CONTENTS/Info.plist" 2>/dev/null || true

if [[ -n "${SIGN_IDENTITY:-}" ]]; then
  # A checkout in an iCloud-synced folder (Documents, Desktop) gets Finder and File Provider
  # attributes that codesign rejects as "detritus". Strip them before signing.
  chmod -R u+w "$APP_DIR"
  xattr -cr "$APP_DIR"
  SPARKLE="$MACOS/Sparkle.framework/Versions/B"
  # Inside out, same order Sparkle documents for a Developer ID app.
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" \
    "$SPARKLE/XPCServices/Downloader.xpc" \
    "$SPARKLE/XPCServices/Installer.xpc" \
    "$SPARKLE/Updater.app" \
    "$SPARKLE/Autoupdate"
  codesign --force --options runtime --timestamp --sign "$SIGN_IDENTITY" \
    "$MACOS/Sparkle.framework"
  codesign --force --options runtime --timestamp \
    --entitlements "$ROOT/Packaging/Entitlements/Sift.entitlements" \
    --sign "$SIGN_IDENTITY" \
    "$APP_DIR"
  echo "Signed with $SIGN_IDENTITY"
fi

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$CONTENTS/Info.plist")"
STAGE="$DIST_DIR/dmg-stage"
DMG="$DIST_DIR/Sift.dmg"

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
