extends SceneTree
## Dev tool: combines screenshots into one contact sheet.
## godot --headless --script res://tools/montage.gd -- --in=/tmp/atk --count=8 --cols=4 --crop=320,120,640,480 --out=/tmp/sheet.png


func _init() -> void:
	var args := {}
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			args[kv[0]] = kv[1]
	var count := int(args.get("count", "4"))
	var cols := int(args.get("cols", "4"))
	var crop: PackedFloat64Array = String(args.get("crop", "0,0,0,0")).split_floats(",")
	var sheet: Image = null
	for i in count:
		var img := Image.load_from_file("%s_%d.png" % [args["in"], i])
		if img == null:
			continue
		var r := Rect2i(int(crop[0]), int(crop[1]), int(crop[2]), int(crop[3]))
		if r.size.x <= 0:
			r = Rect2i(Vector2i.ZERO, img.get_size())
		if sheet == null:
			var rows := int(ceil(float(count) / float(cols)))
			sheet = Image.create(r.size.x * cols, r.size.y * rows, false, img.get_format())
		sheet.blit_rect(img, r, Vector2i((i % cols) * r.size.x, (i / cols) * r.size.y))
	if sheet != null:
		sheet.save_png(String(args.get("out", "/tmp/sheet.png")))
	quit(0)
