#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
XCODE_DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
LOG_DIR=${UI_SMOKE_LOG_DIR:-"$PROJECT_ROOT/tmp/ui-smoke"}
SMOKE_TIMEOUT=${UI_SMOKE_TIMEOUT:-480}
TEMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/emperor-ui-smoke.XXXXXX")
APP_BUNDLE="$TEMP_ROOT/EmperorNative.app"
CONTENTS="$APP_BUNDLE/Contents"

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
HARNESS_EXECUTABLE="$BIN_DIR/emperor-ui-smoke"

mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources" "$LOG_DIR"
cp "$BIN_DIR/EmperorNative" "$CONTENTS/MacOS/EmperorNative"
cp "$PROJECT_ROOT/Packaging/Info.plist" "$CONTENTS/Info.plist"
cp "$PROJECT_ROOT/Packaging/AppIcon.icns" "$CONTENTS/Resources/AppIcon.icns"
chmod 755 "$CONTENTS/MacOS/EmperorNative"
codesign --force --options runtime \
    --entitlements "$PROJECT_ROOT/Packaging/EmperorNative.entitlements" \
    --sign - --timestamp=none "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

"$HARNESS_EXECUTABLE" \
    --app "$APP_BUNDLE" \
    --log-dir "$LOG_DIR" \
    --timeout "$SMOKE_TIMEOUT"
