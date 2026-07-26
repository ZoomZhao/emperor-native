#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
XCODE_DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
APP_BUNDLE="$PROJECT_ROOT/dist/EmperorNative.app"
CONTENTS="$APP_BUNDLE/Contents"
DIST_DIR="$PROJECT_ROOT/dist"
VERSION=1.0.0
ARCHIVE_NAME="EmperorNative-$VERSION-macos-arm64.zip"
ARCHIVE="$DIST_DIR/$ARCHIVE_NAME"
ENTITLEMENTS="$PROJECT_ROOT/Packaging/EmperorNative.entitlements"
SIGNING_IDENTITY=${SIGNING_IDENTITY:--}
GAME_DATA_SRC="$PROJECT_ROOT/GameData"
GAME_DATA_DST="$CONTENTS/Resources/GameData"

if [ ! -d "$GAME_DATA_SRC/DATA" ] || [ ! -d "$GAME_DATA_SRC/Cities" ] || [ ! -d "$GAME_DATA_SRC/Campaigns" ] || [ ! -d "$GAME_DATA_SRC/Model" ] || [ ! -d "$GAME_DATA_SRC/Audio" ]; then
    echo "package-app: missing GameData at $GAME_DATA_SRC" >&2
    exit 66
fi

if [ "${SKIP_RELEASE_GATE:-0}" != "1" ]; then
    DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" "$PROJECT_ROOT/scripts/release-gate.sh"
fi

DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" swift build --package-path "$PROJECT_ROOT" -c release --product EmperorNative

rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$PROJECT_ROOT/.build/arm64-apple-macosx/release/EmperorNative" "$CONTENTS/MacOS/EmperorNative"
cp "$PROJECT_ROOT/Packaging/Info.plist" "$CONTENTS/Info.plist"
cp "$PROJECT_ROOT/Packaging/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
mkdir -p "$GAME_DATA_DST"
rsync -a --exclude 'DATA_IMAGES/' "$GAME_DATA_SRC/" "$GAME_DATA_DST/"
chmod 755 "$CONTENTS/MacOS/EmperorNative"

if [ "$SIGNING_IDENTITY" = "-" ]; then
    codesign --force --options runtime --entitlements "$ENTITLEMENTS" \
        --sign - --timestamp=none "$APP_BUNDLE"
else
    codesign --force --options runtime --entitlements "$ENTITLEMENTS" \
        --sign "$SIGNING_IDENTITY" --timestamp "$APP_BUNDLE"
fi
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

# NOTARY_PROFILE is the name created by `xcrun notarytool store-credentials`.
# It is intentionally optional so local clean-room builds remain reproducible
# without storing Apple credentials in the repository.
if [ -n "${NOTARY_PROFILE:-}" ]; then
    NOTARY_ARCHIVE="$DIST_DIR/EmperorNative-notary.zip"
    ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$NOTARY_ARCHIVE"
    xcrun notarytool submit "$NOTARY_ARCHIVE" \
        --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$APP_BUNDLE"
    rm -f "$NOTARY_ARCHIVE"
fi

ditto -c -k --sequesterRsrc --keepParent "$APP_BUNDLE" "$ARCHIVE"
(
    cd "$DIST_DIR"
    shasum -a 256 "$ARCHIVE_NAME" > "$ARCHIVE_NAME.sha256"
)
printf '%s\n%s\n%s\n' "$APP_BUNDLE" "$ARCHIVE" "$ARCHIVE.sha256"
