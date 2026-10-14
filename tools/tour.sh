#!/bin/sh
# Visual tour: captures the Necropolis at several player positions and builds a contact sheet.
# Usage: sh tools/tour.sh OUT_DIR "x,y,z" "x,y,z" ...
cd "$(dirname "$0")/.." || exit 1
OUT=$1; shift
i=0
for pos in "$@"; do
  godot --path . --resolution 960x540 res://tests/visual/capture.tscn -- --scene=res://scenes/levels/necropolis.tscn --out=$OUT/tour$i --frames=${FRAMES:-150} --player=$pos > /dev/null 2>&1
  mv $OUT/tour${i}_0.png $OUT/tour_$i.png 2>/dev/null
  i=$((i+1))
done
python3 - "$OUT" "$i" <<'PY'
import sys
from PIL import Image
out, n = sys.argv[1], int(sys.argv[2])
ims = [Image.open("%s/tour_%d.png" % (out, k)).convert("RGB").resize((960, 540)) for k in range(n)]
cols = 3
rows = (n + cols - 1) // cols
c = Image.new("RGB", (960 * cols, 540 * rows))
for k, im in enumerate(ims):
    c.paste(im, ((k % cols) * 960, (k // cols) * 540))
c.save("%s/tour_sheet.png" % out)
PY
