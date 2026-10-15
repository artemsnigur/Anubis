extends Node
## Visual check harness (needs a real window, not --headless).
## godot res://tests/visual/capture.tscn -- --scene=res://scenes/levels/test_arena.tscn --out=/tmp/shot --frames=90 [--shots=3 --interval=30]
## Saves PNG screenshots so changes can be inspected without the editor.

var _args: Dictionary = {}
var _frame: int = 0
var _shot: int = 0
var _scene: Node


func _ready() -> void:
	# Stay out of the user's way: never take focus, sit behind other windows.
	var w := get_window()
	w.set_flag(Window.FLAG_NO_FOCUS, true)
	w.set_flag(Window.FLAG_ALWAYS_ON_TOP, false)
	# Ignore every key / mouse event: if the window ever gets focus, typing elsewhere
	# must not pause the game or change settings.
	w.set_disable_input(true)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1]
	var path: String = _args.get("scene", "res://scenes/levels/test_arena.tscn")
	var ps := load(path) as PackedScene
	_scene = ps.instantiate()
	add_child(_scene)
	if _args.has("player"):
		var v := String(_args["player"]).split_floats(",")
		var pl := _scene.get("player") as Node3D
		if pl != null:
			pl.call(&"teleport_to", Vector3(v[0], v[1], v[2]), 0.0)
			var cam: Variant = _scene.get("camera")
			if cam != null:
				(cam as Node).call_deferred(&"snap_to_target")
	if _args.has("setup"):
		var setup_script := load(String(_args["setup"])) as GDScript
		var helper: Node = setup_script.new()
		add_child(helper)
		helper.call(&"setup", _scene, _args)


func _process(_delta: float) -> void:
	_frame += 1
	var first := int(_args.get("frames", "90"))
	var shots := int(_args.get("shots", "1"))
	var interval := int(_args.get("interval", "30"))
	if _frame >= first + _shot * interval:
		print("capture: fps=%d draw_calls=%d objects=%d" % [Engine.get_frames_per_second(), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)])
		var img := get_viewport().get_texture().get_image()
		var out: String = _args.get("out", "/tmp/shot")
		img.save_png("%s_%d.png" % [out, _shot])
		_shot += 1
		if _shot >= shots:
			get_tree().quit()
