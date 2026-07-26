#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
XCODE_DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
APP_BUNDLE="$PROJECT_ROOT/dist/EmperorUISmoke.app"
CONTENTS="$APP_BUNDLE/Contents"
EXECUTABLE="$CONTENTS/MacOS/EmperorUISmoke"
PACKAGE_HASH_FILE="$CONTENTS/Resources/PackageInput.sha256"
INFO_PLIST="$PROJECT_ROOT/Packaging/EmperorUISmoke-Info.plist"
SIGNING_REQUIREMENT='=designated => identifier "com.openai.EmperorNative.UISmoke"'

DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" swift build \
    --package-path "$PROJECT_ROOT" --product emperor-ui-smoke >&2
BIN_DIR=$(DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" swift build \
    --package-path "$PROJECT_ROOT" --show-bin-path)
BUILT_EXECUTABLE="$BIN_DIR/emperor-ui-smoke"
BUILT_EXECUTABLE_HASH=$(shasum -a 256 "$BUILT_EXECUTABLE" | awk '{print $1}')
INFO_PLIST_HASH=$(shasum -a 256 "$INFO_PLIST" | awk '{print $1}')
PACKAGE_INPUT_HASH=$(printf '%s\n%s\n%s\n' \
    "$BUILT_EXECUTABLE_HASH" "$INFO_PLIST_HASH" "$SIGNING_REQUIREMENT" \
    | shasum -a 256 | awk '{print $1}')
INSTALLED_PACKAGE_HASH=
if [ -f "$PACKAGE_HASH_FILE" ]; then
    INSTALLED_PACKAGE_HASH=$(sed -n '1p' "$PACKAGE_HASH_FILE")
fi

if [ ! -f "$EXECUTABLE" ] || [ "$PACKAGE_INPUT_HASH" != "$INSTALLED_PACKAGE_HASH" ]; then
    mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
    cp "$BUILT_EXECUTABLE" "$EXECUTABLE"
    cp "$INFO_PLIST" "$CONTENTS/Info.plist"
    printf '%s\n' "$PACKAGE_INPUT_HASH" > "$PACKAGE_HASH_FILE"
    chmod 755 "$EXECUTABLE"
    codesign --force --options runtime \
        --identifier com.openai.EmperorNative.UISmoke \
        --requirements "$SIGNING_REQUIREMENT" \
        --sign - --timestamp=none "$APP_BUNDLE" >&2
fi

codesign --verify --deep --strict "$APP_BUNDLE" >&2
printf '%s\n' "$APP_BUNDLE"
