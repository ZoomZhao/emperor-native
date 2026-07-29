#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
XCODE_DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
LOG_DIR=${UI_SMOKE_LOG_DIR:-"$PROJECT_ROOT/tmp/ui-smoke-qin1"}
TEMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/emperor-qin1-ui-smoke.XXXXXX")
APP_BUNDLE="$TEMP_ROOT/EmperorNative.app"
CONTENTS="$APP_BUNDLE/Contents"
EXECUTABLE_NAME="EmperorNativeQinSmoke"

cleanup() {
    rm -rf "$TEMP_ROOT"
}
trap cleanup EXIT INT TERM

DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" swift build \
    --package-path "$PROJECT_ROOT" --product EmperorNative
DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" swift build \
    --package-path "$PROJECT_ROOT" --product emperor-ui-smoke
BIN_DIR=$(DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" swift build \
    --package-path "$PROJECT_ROOT" --show-bin-path)

mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$LOG_DIR"
cp "$BIN_DIR/EmperorNative" "$CONTENTS/MacOS/$EXECUTABLE_NAME"
cp "$PROJECT_ROOT/Packaging/Info.plist" "$CONTENTS/Info.plist"
cp "$PROJECT_ROOT/Packaging/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
/usr/libexec/PlistBuddy \
    -c "Set :CFBundleIdentifier com.openai.EmperorNative.QinSmoke" \
    -c "Set :CFBundleExecutable $EXECUTABLE_NAME" \
    -c "Set :CFBundleName EmperorNative Qin Smoke" \
    -c "Set :CFBundleDisplayName EmperorNative Qin Smoke" \
    "$CONTENTS/Info.plist"
chmod 755 "$CONTENTS/MacOS/$EXECUTABLE_NAME"
codesign --force --options runtime \
    --entitlements "$PROJECT_ROOT/Packaging/EmperorNative.entitlements" \
    --sign - --timestamp=none "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

"$BIN_DIR/emperor-ui-smoke" \
    --app "$APP_BUNDLE" \
    --log-dir "$LOG_DIR" \
    --snapshot-qin
