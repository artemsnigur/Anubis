#!/bin/sh
# Runs every headless test scene and summarises exit code, FAIL lines and engine errors / warnings.
# Usage: sh tools/run_tests.sh [test_name ...]   (from the project root; default = all tests)
cd "$(dirname "$0")/.." || exit 1
TESTS="$*"
[ -z "$TESTS" ] && TESTS="smoke_test combat_test loop_test ai_test player_motion_test level_test boss_test model_rig_test menu_flow_test feel_test preset_test full_run_test"
LOGDIR="${TMPDIR:-/tmp}/duat_tests"
mkdir -p "$LOGDIR"
STATUS=0
# Tests delete / write the save and the settings: keep the player's own files safe.
USERDIR="$HOME/Library/Application Support/Godot/app_userdata/Heart of the Duat"
[ -d "$HOME/.local/share/godot/app_userdata/Heart of the Duat" ] && USERDIR="$HOME/.local/share/godot/app_userdata/Heart of the Duat"
for f in duat_save.json settings.cfg; do
  rm -f "$LOGDIR/backup_$f"
  [ -f "$USERDIR/$f" ] && cp "$USERDIR/$f" "$LOGDIR/backup_$f"
done
for t in $TESTS; do
  godot --headless "res://tests/$t.tscn" > "$LOGDIR/$t.log" 2>&1
  CODE=$?
  FAILS=$(grep -c "^FAIL" "$LOGDIR/$t.log")
  ERRS=$(grep -c "SCRIPT ERROR\|^ERROR" "$LOGDIR/$t.log")
  WARNS=$(grep -c "^WARNING" "$LOGDIR/$t.log")
  echo "$t: exit=$CODE FAIL=$FAILS ERR=$ERRS WARN=$WARNS"
  if [ "$CODE" != "0" ] || [ "$FAILS" != "0" ] || [ "$ERRS" != "0" ] || [ "$WARNS" != "0" ]; then STATUS=1; fi
done
for f in duat_save.json settings.cfg; do
  if [ -f "$LOGDIR/backup_$f" ]; then cp "$LOGDIR/backup_$f" "$USERDIR/$f"; else rm -f "$USERDIR/$f"; fi
done
echo "logs: $LOGDIR"
exit $STATUS
