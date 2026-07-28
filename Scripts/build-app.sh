#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."

CONFIG="${1:-debug}"
swift build -c "$CONFIG"

BUILD_DIR=".build/$CONFIG"
APP_DIR="$BUILD_DIR/FlacPlayer.app"
EXECUTABLE="$APP_DIR/Contents/MacOS/FlacPlayer"
FRAMEWORKS_DIR="$APP_DIR/Contents/Frameworks"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources" "$FRAMEWORKS_DIR"
cp "Sources/FlacPlayer/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "Sources/FlacPlayer/Resources/AppIcon.icns" "$APP_DIR/Contents/Resources/AppIcon.icns"
cp "$BUILD_DIR/FlacPlayer" "$EXECUTABLE"

# swift build links libFLAC/libogg at their absolute Homebrew paths, which
# only exist on machines with those exact formulae installed. Bundle both
# dylibs into the app and rewrite load commands to @executable_path-relative
# ones so the app runs (and notarizes) standalone.
FLAC_DYLIB="$(otool -L "$EXECUTABLE" | awk '/libFLAC/{print $1; exit}')"
OGG_DYLIB="$(otool -L "$FLAC_DYLIB" | awk '/libogg/{print $1; exit}')"

cp "$FLAC_DYLIB" "$FRAMEWORKS_DIR/"
cp "$OGG_DYLIB" "$FRAMEWORKS_DIR/"
chmod u+w "$FRAMEWORKS_DIR/$(basename "$FLAC_DYLIB")" "$FRAMEWORKS_DIR/$(basename "$OGG_DYLIB")"

install_name_tool -change "$FLAC_DYLIB" "@executable_path/../Frameworks/$(basename "$FLAC_DYLIB")" "$EXECUTABLE"
install_name_tool -id "@executable_path/../Frameworks/$(basename "$FLAC_DYLIB")" "$FRAMEWORKS_DIR/$(basename "$FLAC_DYLIB")"
install_name_tool -change "$OGG_DYLIB" "@loader_path/$(basename "$OGG_DYLIB")" "$FRAMEWORKS_DIR/$(basename "$FLAC_DYLIB")"
install_name_tool -id "@loader_path/$(basename "$OGG_DYLIB")" "$FRAMEWORKS_DIR/$(basename "$OGG_DYLIB")"

# install_name_tool invalidates whatever signature was already on these
# binaries (Homebrew's on the dylibs, swift build's ad-hoc one on the
# executable) — macOS refuses to run an invalidly-signed binary at all, so
# every binary in the bundle needs re-signing after the rewrites above.
# Ad-hoc (-) is enough for local runs; notarize.sh re-signs everything with
# a real Developer ID identity for distribution.
codesign --force --sign - "$FRAMEWORKS_DIR/$(basename "$OGG_DYLIB")"
codesign --force --sign - "$FRAMEWORKS_DIR/$(basename "$FLAC_DYLIB")"
codesign --force --sign - "$EXECUTABLE"

echo "Built $APP_DIR"
