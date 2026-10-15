extends Node
## Capture helper: drives the player to attack the dummy in front of it.

var player: Player
var _t: float = 0.0
var _presses: Array = []
## Optional timed screenshots (--times=1.52,1.6 --out=prefix): exact game times.
var _times: PackedFloat64Array = []
var _out: String = "/tmp/attack"
var _shot: int = 0


func setup(scene: Node, args: Dictionary) -> void:
	player = scene.get("player")
	player.input.bot_enabled = true
	player.teleport_to(Vector3(0.0, 0.1, 1.9), 0.0)
	var cam := scene.get("camera") as GameCamera
	cam.zoom = float(args.get("zoom", "1.0"))
	cam.call_deferred(&"snap_to_target")
	_out = String(args.get("out", _out))
	if args.has("times"):
		_times = PackedFloat64Array(Array(String(args["times"]).split_floats(",")))
	var kind := String(args.get("action", "light"))
	match kind:
		"light":
			_presses = [[1.5, &"attack_light"], [1.75, &"attack_light"], [2.05, &"attack_light"]]
		"heavy":
			_presses = [[1.5, &"attack_heavy"]]
		"ranged":
			player.energy = 4.0
			player.teleport_to(Vector3(0.0, 0.1, 6.0), 0.0)
			_presses = [[1.5, &"ranged"]]
		"dodge":
			_presses = [[1.5, &"dodge"]]


func _physics_process(delta: float) -> void:
	_t += delta
	for p: Array in _presses:
		if absf(_t - float(p[0])) < delta * 0.5:
			player.input.bot_press(p[1])
	player.input.bot_aim = Vector3.FORWARD
	if _shot < _times.size() and _t >= _times[_shot]:
		_save.call_deferred(_shot, _t)
		_shot += 1


func _save(i: int, t: float) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s_t%d.png" % [_out, i])
	print("setup_attack: shot %d at t=%.3f state=%s" % [i, t, player.fsm.current_name()])
