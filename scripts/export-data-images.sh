#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
XCODE_DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
DATA_DIRECTORY="$PROJECT_ROOT/GameData/DATA"
OUTPUT_ROOT="$PROJECT_ROOT/GameData/DATA_IMAGES"

if [ ! -d "$DATA_DIRECTORY" ]; then
    echo "export-data-images: missing DATA directory at $DATA_DIRECTORY" >&2
    exit 66
fi

case "$OUTPUT_ROOT" in
    "$PROJECT_ROOT/GameData/DATA_IMAGES") ;;
    *)
        echo "export-data-images: refusing unexpected output path $OUTPUT_ROOT" >&2
        exit 64
        ;;
esac

if [ -e "$OUTPUT_ROOT" ]; then
    rm -rf "$OUTPUT_ROOT"
fi
mkdir -p "$OUTPUT_ROOT"

DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" swift build \
    --package-path "$PROJECT_ROOT" --product emperor-inspect
BIN_DIRECTORY=$(DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" swift build \
    --package-path "$PROJECT_ROOT" --show-bin-path)
"$BIN_DIRECTORY/emperor-inspect" \
    sg3-export-all "$DATA_DIRECTORY" "$OUTPUT_ROOT"
