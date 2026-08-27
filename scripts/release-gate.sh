#!/bin/sh
set -eu

PROJECT_ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
XCODE_DEVELOPER_DIR=${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}
DATA_ROOT="$PROJECT_ROOT/GameData"
XIA1_PLAYTHROUGH="$PROJECT_ROOT/Tests/EmperorGameplayTests/Xia1PlayerPlaythroughTests.swift"
XIA2_PLAYTHROUGH="$PROJECT_ROOT/Tests/EmperorGameplayTests/Xia2PlayerPlaythroughTests.swift"
UI_HARNESS="$PROJECT_ROOT/Sources/EmperorNativeUISmoke/main.swift"
DIRECTED_LOG=$(mktemp "${TMPDIR:-/tmp}/emperor-release-gate.XXXXXX")

cleanup() {
    rm -f "$DIRECTED_LOG"
}
trap cleanup EXIT INT TERM

if [ ! -d "$DATA_ROOT/DATA" ] || [ ! -d "$DATA_ROOT/Cities" ] || [ ! -d "$DATA_ROOT/Campaigns" ] || [ ! -d "$DATA_ROOT/Model" ] || [ ! -d "$DATA_ROOT/Audio" ]; then
    echo "release-gate: missing local GameData at $DATA_ROOT" >&2
    exit 66
fi

BANNED_PATTERN='admitResidents|addHouse|receiveCampaignCommodityGift|CampaignGoalProgressSnapshot|assignedWorkers[[:space:]]*:[[:space:]]*[1-9]|houseLevelID[[:space:]]*=[^=]|serviceCoverage[[:space:]]*=[^=]|housingEvolutionEnabled|publicSafetyEnabled|\.outcome[[:space:]]*=[^=]'
if rg -n "$BANNED_PATTERN" "$XIA1_PLAYTHROUGH" "$XIA2_PLAYTHROUGH" "$UI_HARNESS"; then
    echo 'release-gate: forbidden state injection found in player replay' >&2
    exit 65
fi

cd "$PROJECT_ROOT"
if ! DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" swift test \
    --filter GameSessionControllerTests >"$DIRECTED_LOG" 2>&1; then
    cat "$DIRECTED_LOG"
    exit 1
fi
if ! DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" swift test \
    --filter Xia1PlayerPlaythroughTests >>"$DIRECTED_LOG" 2>&1; then
    cat "$DIRECTED_LOG"
    exit 1
fi
if ! DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" swift test \
    --filter Xia2PlayerPlaythroughTests >>"$DIRECTED_LOG" 2>&1; then
    cat "$DIRECTED_LOG"
    exit 1
fi
cat "$DIRECTED_LOG"
if rg -i 'skipped|XCTSkip' "$DIRECTED_LOG"; then
    echo 'release-gate: directed gameplay gate contained a skipped test' >&2
    exit 65
fi

DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" swift test
DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" swift build
DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" swift build --product emperor-ui-smoke

if [ "${RUN_UI_SMOKE:-0}" = "1" ]; then
    DEVELOPER_DIR="$XCODE_DEVELOPER_DIR" "$PROJECT_ROOT/scripts/xia1-ui-smoke.sh"
fi

echo 'release-gate: PASS'
