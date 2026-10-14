#!/bin/sh
# Runs a windowed Godot instance (for screenshots) without keeping focus (macOS):
# remembers the frontmost app and, for the first seconds after launch, hands focus
# back with `open -b` every time Godot activates itself (process start + window).
# Usage: sh tools/bg_godot.sh <godot args...>
cd "$(dirname "$0")/.." || exit 1
PREV=$(osascript -e 'tell application "System Events" to get bundle identifier of first application process whose frontmost is true' 2>/dev/null)
godot --path . --position 0,0 "$@" > "${BG_LOG:-/tmp/bg_godot.log}" 2>&1 &
PID=$!
end=$(( $(date +%s) + 12 ))
while [ "$(date +%s)" -lt "$end" ] && kill -0 $PID 2>/dev/null; do
  FRONT=$(osascript -e 'tell application "System Events" to get name of first application process whose frontmost is true' 2>/dev/null | tr 'A-Z' 'a-z')
  if [ "$FRONT" = "godot" ] && [ -n "$PREV" ] && [ "$PREV" != "missing value" ]; then
    open -b "$PREV"
  fi
  sleep 0.1
done
wait $PID
