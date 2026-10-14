extends SceneTree
## Dev tool: compiles every GDScript in the project and reports failures.
## Used by tools/check.sh together with an override.cfg that turns warnings into errors.
## The work runs on the first frame so autoload singletons are registered.

var _done := false


func _process(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var files: PackedStringArray = []
	_collect("res://", files)
	var failed := 0
	for f in files:
		var s := load(f) as Script
		if s == null:
			failed += 1
			printerr("SCRIPT FAILED: ", f)
	print("check_scripts: %d scripts, %d failed" % [files.size(), failed])
	quit(1 if failed > 0 else 0)
	return false


func _collect(dir_path: String, out: PackedStringArray) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for d in dir.get_directories():
		if d.begins_with("."):
			continue
		_collect(dir_path.path_join(d), out)
	for f in dir.get_files():
		if f.ends_with(".gd"):
			out.append(dir_path.path_join(f))
