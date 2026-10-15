extends Node
## Capture helper: the hero runs right, then reverses (pivot), then stops (skid).
## Takes its own screenshots at fixed game times (--times=1.6,2.05,...; --out=prefix).
## --zoom=0.45 for a close-up of the secondary motion / lean.

var player: Player
var _t: float = 0.0
var _times: PackedFloat64Array = [1.6, 2.04, 2.1, 2.2, 2.66, 2.75]
var _out: String = "/tmp/run"
var _shot: int = 0


func setup(scene: Node, args: Dictionary) -> void:
	player = scene.get("player")
	player.input.bot_enabled = true
	player.teleport_to(Vector3(-6.0, 0.1, 8.0), 0.0)
	var cam := scene.get("camera") as GameCamera
	cam.zoom = float(args.get("zoom", "0.45"))
	cam.call_deferred(&"snap_to_target")
	_out = String(args.get("out", _out))
	if args.has("times"):
		_times = PackedFloat64Array(Array(String(args["times"]).split_floats(",")))


func _physics_process(delta: float) -> void:
	_t += delta
	if _t < 1.0:
		player.input.bot_move = Vector2.ZERO
	elif _t < 2.0:
		player.input.bot_move = Vector2(1, 0)
	elif _t < 2.6:
		player.input.bot_move = Vector2(-1, 0)
	else:
		player.input.bot_move = Vector2.ZERO
	if _shot < _times.size() and _t >= _times[_shot]:
		_save.call_deferred(_shot)
		_shot += 1


func _save(i: int) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_t%d.png" % [_out, i])
	print("setup_run: shot %d at t=%.2f state=%s speed=%.1f" % [i, _t, player.fsm.current_name(), player.velocity.length()])
