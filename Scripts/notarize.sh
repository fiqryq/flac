#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

# Requires:
#   1. A "Developer ID Application" certificate in your keychain (Apple
#      Developer Program enrollment required — the "Apple Development"
#      certificate Xcode creates for free is NOT sufficient for this;
#      it's only valid for running on your own registered devices).
#   2. Notarization credentials stored once via:
#        xcrun notarytool store-credentials "flac-notary" \
#          --apple-id "you@example.com" --team-id TEAMID --password "app-specific-password"
#      (or an API key — see `xcrun notarytool store-credentials --help`).
#
# Usage:
#   DEVELOPER_ID_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
#   NOTARY_PROFILE="flac-notary" \
#   ./Scripts/notarize.sh

: "${DEVELOPER_ID_IDENTITY:?Set DEVELOPER_ID_IDENTITY to your \"Developer ID Application: ...\" identity (see: security find-identity -v -p codesigning)}"
: "${NOTARY_PROFILE:?Set NOTARY_PROFILE to the keychain profile name from 'xcrun notarytool store-credentials'}"

./Scripts/build-app.sh release

APP_DIR=".build/release/FlacPlayer.app"
ZIP_PATH=".build/release/FlacPlayer.zip"

echo "==> Re-signing with Developer ID + hardened runtime"
codesign --force --options runtime --timestamp \
    --sign "$DEVELOPER_ID_IDENTITY" \
    "$APP_DIR/Contents/Frameworks/libogg.0.dylib"
codesign --force --options runtime --timestamp \
    --sign "$DEVELOPER_ID_IDENTITY" \
    "$APP_DIR/Contents/Frameworks/libFLAC.14.dylib"
codesign --force --options runtime --timestamp \
    --entitlements Entitlements.plist \
    --sign "$DEVELOPER_ID_IDENTITY" \
    "$APP_DIR/Contents/MacOS/FlacPlayer"
codesign --force --options runtime --timestamp \
    --entitlements Entitlements.plist \
    --sign "$DEVELOPER_ID_IDENTITY" \
    "$APP_DIR"

echo "==> Verifying signature"
codesign --verify --deep --strict --verbose=2 "$APP_DIR"

echo "==> Zipping for submission"
rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_DIR" "$ZIP_PATH"

echo "==> Submitting to Apple notary service (this can take several minutes)"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling notarization ticket"
xcrun stapler staple "$APP_DIR"

echo "==> Final Gatekeeper check"
spctl -a -vvv --type execute "$APP_DIR"

echo "Notarized: $APP_DIR"
