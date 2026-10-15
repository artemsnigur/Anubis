extends Node
## Capture helper: plays scripted segments (run / turn / stop, light combo on a dummy,
## rolls, charged heavy) and saves every `--step`-th physics frame as PNG into --dir.
## Run with a fixed frame rate so frames are evenly spaced in game time:
## godot --fixed-fps 60 --resolution 960x540 res://tests/visual/capture.tscn -- \
##   --setup=res://tests/visual/setup_showcase.gd --dir=/tmp/show --frames=100000 [--only=combo]

const DUMMY := preload("res://scenes/enemies/training_dummy.tscn")

var scene: Level
var player: Player
var dummy: EnemyBase
var _dir: String = "/tmp/show"
var _step: int = 2
var _only: String = ""


func setup(p_scene: Node, args: Dictionary) -> void:
	scene = p_scene as Level
	player = scene.player
	player.input.bot_enabled = true
	_dir = String(args.get("dir", _dir))
	_step = int(args.get("step", "2"))
	_only = String(args.get("only", ""))
	DirAccess.make_dir_recursive_absolute(_dir)
	var cam := scene.camera
	cam.zoom = float(args.get("zoom", "0.62"))
	# Review captures: keep the hero centred (the real follow lags on purpose).
	if args.has("tight"):
		cam.use_feel_preset = false
		cam.follow_damping = 30.0
		cam.look_ahead_scale = 0.0
	_run.call_deferred()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Records `seconds` of game time while `driver` runs (called every physics frame with t).
func _record(segment: String, seconds: float, driver: Callable) -> void:
	var n := int(seconds * 60.0)
	for i in n:
		driver.call(float(i) / 60.0)
		await get_tree().physics_frame
		if i % _step == 0:
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("%s/%s_%03d.png" % [_dir, segment, i / _step])
	print("showcase: recorded ", segment)


func _place(pos: Vector3, yaw: float) -> void:
	player.input.bot_move = Vector2.ZERO
	player.teleport_to(pos, yaw)
	player.fsm.transition_to(&"Move")
	scene.camera.snap_to_target()
	await _frames(20)


func _run() -> void:
	await _frames(60)
	# The arena's own dummy at the origin is the sparring partner.
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var e := n as EnemyBase
		if e != null and e.global_position.length() < 0.5:
			dummy = e
	if dummy == null:
		dummy = DUMMY.instantiate() as EnemyBase
		scene.add_child(dummy)
	if _only == "" or _only == "run":
		await _place(Vector3(-7, 0.1, 9), 0.0)
		await _record("run", 3.6, func(t: float) -> void:
			player.input.bot_move = Vector2.ZERO if t < 0.3 else (Vector2(1, 0) if t < 1.7 else (Vector2(-1, 0) if t < 2.8 else Vector2.ZERO)))
	if _only == "" or _only == "combo":
		dummy.health.revive_full()
		dummy.poise.restore()
		await _place(Vector3(0, 0.1, 2.0), 0.0)
		player.input.bot_aim = Vector3.FORWARD
		await _record("combo", 2.6, func(t: float) -> void:
			for p: float in [0.2, 0.55, 1.0]:
				if absf(t - p) < 0.5 / 60.0:
					player.input.bot_press(&"attack_light"))
	if _only == "" or _only == "dodge":
		await _place(Vector3(-4, 0.1, 7), 0.0)
		await _record("dodge", 2.2, func(t: float) -> void:
			player.input.bot_move = Vector2(1, 0) if t > 0.15 and t < 0.25 or t > 1.0 and t < 1.1 else Vector2.ZERO
			if absf(t - 0.2) < 0.5 / 60.0 or absf(t - 1.05) < 0.5 / 60.0:
				player.input.bot_press(&"dodge"))
	if _only == "" or _only == "heavy":
		dummy.health.revive_full()
		dummy.poise.restore()
		await _place(Vector3(0, 0.1, 2.2), 0.0)
		player.input.bot_aim = Vector3.FORWARD
		await _record("heavy", 2.6, func(t: float) -> void:
			if absf(t - 0.2) < 0.5 / 60.0:
				player.input.bot_hold(&"attack_heavy", true)
				player.input.bot_press(&"attack_heavy")
			if absf(t - 1.25) < 0.5 / 60.0:
				player.input.bot_hold(&"attack_heavy", false))
	print("showcase: done")
	get_tree().quit()
