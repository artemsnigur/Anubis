#!/bin/sh
# Copies the project to a temporary snapshot and runs tools/run_tests.sh there, so the
# working tree can keep changing while the (slow) suite runs.
# Usage: sh tools/snapshot_tests.sh <snapshot dir> [test_name ...]
SRC="$(cd "$(dirname "$0")/.." && pwd)"
DST="$1"
shift
rm -rf "$DST"
mkdir -p "$DST"
rsync -a --exclude .git "$SRC/" "$DST/"
cd "$DST" || exit 1
godot --headless --import > /dev/null 2>&1
TMPDIR="$DST/.test_logs/" sh tools/run_tests.sh "$@"
