#!/bin/sh
# Runs a windowed Godot instance (for screenshots) without keeping focus (macOS):
# remembers the frontmost app and, for as long as Godot runs, hands focus back with
# `open -b` whenever Godot becomes the frontmost app. Long captures (minutes) used to
# grab the keyboard after the first seconds; the guard now covers the whole run.
# Capture scenes also ignore all input (tests/visual/capture.gd), so stray keys are harmless.
# Usage: sh tools/bg_godot.sh <godot args...>
cd "$(dirname "$0")/.." || exit 1
PREV=$(osascript -e 'tell application "System Events" to get bundle identifier of first application process whose frontmost is true' 2>/dev/null)
godot --path . --position 0,0 "$@" > "${BG_LOG:-/tmp/bg_godot.log}" 2>&1 &
PID=$!
start=$(date +%s)
while kill -0 $PID 2>/dev/null; do
  FRONT=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null | tr 'A-Z' 'a-z')
  if [ "$FRONT" = "godot" ] && [ -n "$PREV" ] && [ "$PREV" != "missing value" ] && [ "$PREV" != "org.godotengine.godot" ]; then
    open -b "$PREV"
  fi
  # Poll fast while the window appears, then calmly for the rest of the run.
  if [ $(( $(date +%s) - start )) -lt 12 ]; then sleep 0.1; else sleep 0.4; fi
done
wait $PID
