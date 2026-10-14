extends Node
## Headless check of movement feel numbers: run speed, accel time, dodge distance,
## i-frame window, attack chain + input buffer, dodge cancel.
## godot --headless res://tests/player_motion_test.tscn

var arena: Node3D
var player: Player
var _step: int = 0
var _t: float = 0.0
var _log: PackedStringArray = []
var _mark: Vector3
var _iframe_frames: int = 0
var _states_seen: Dictionary = {}
var _failures: int = 0


func _ready() -> void:
	# Watchdog: never hang a CI run.
	get_tree().create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("player_motion_test: TIMEOUT")
		get_tree().quit(2))
	arena = (load("res://scenes/levels/test_arena.tscn") as PackedScene).instantiate()
	arena.set("spawn_dummies", false)
	add_child(arena)
	player = arena.get("player")
	player.input.bot_enabled = true
	player.fsm.state_changed.connect(func(_f: StringName, to: StringName) -> void: _states_seen[to] = true)


func _check(cond: bool, msg: String) -> void:
	_log.append(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_failures += 1


func _physics_process(delta: float) -> void:
	_t += delta
	match _step:
		0:
			if _t > 0.3:
				_mark = player.global_position
				player.input.bot_move = Vector2(1, 0)
				_t = 0.0
				_step = 1
		1:
			if _t >= 0.1 and _t < 0.1 + delta:
				_check(player.move_velocity.length() > 5.0, "reaches near full speed in 0.1s (%.2f m/s)" % player.move_velocity.length())
			if _t >= 1.0:
				var spd := player.move_velocity.length()
				_check(absf(spd - 6.0) < 0.3, "run speed ~6 m/s (%.2f)" % spd)
				player.input.bot_move = Vector2.ZERO
				_t = 0.0
				_step = 2
		2:
			if _t >= 0.12:
				_check(player.move_velocity.length() < 0.5, "stops within 0.12s (%.2f m/s)" % player.move_velocity.length())
				_mark = player.global_position
				player.input.bot_press(&"dodge")
				_t = 0.0
				_iframe_frames = 0
				_step = 3
		3:
			if player.hurtbox.invulnerable:
				_iframe_frames += 1
			if _t >= 0.5:
				var d := Vector2(player.global_position.x - _mark.x, player.global_position.z - _mark.z).length()
				_check(absf(d - 4.5) < 0.6, "dodge distance ~4.5 m (%.2f)" % d)
				var iframe_time := _iframe_frames / 60.0
				_check(absf(iframe_time - 0.2) < 0.05, "i-frames ~0.2 s (%.3f)" % iframe_time)
				_t = 0.0
				_step = 4
		4:
			# Attack chain via buffered presses.
			if _t < 0.02:
				player.input.bot_press(&"attack_light")
			if absf(_t - 0.25) < delta * 0.5:
				player.input.bot_press(&"attack_light")
			if absf(_t - 0.55) < delta * 0.5:
				player.input.bot_press(&"attack_light")
			if _t > 0.3 and player.fsm.is_in(&"Attack"):
				var st := player.fsm.current
				_states_seen["chain_%d" % int(st.get("index"))] = true
			if _t >= 1.6:
				_check(_states_seen.has("chain_1"), "light chain reaches hit 2")
				_check(_states_seen.has("chain_2"), "light chain reaches hit 3")
				_t = 0.0
				_step = 5
		5:
			# Attack then dodge-cancel the recovery.
			if _t < 0.02:
				player.input.bot_press(&"attack_light")
			if absf(_t - 0.2) < delta * 0.5:
				player.input.bot_press(&"dodge")
			if _t >= 0.3:
				_check(player.fsm.is_in(&"Dodge"), "attack recovery cancels into dodge (state %s)" % player.fsm.current_name())
				_t = 0.0
				_step = 6
		6:
			if _t >= 0.6:
				_check(_states_seen.has(&"Dodge") and _states_seen.has(&"Attack"), "states visited")
				for l in _log:
					print(l)
				print("player_motion_test: %d failures" % _failures)
				get_tree().quit(1 if _failures > 0 else 0)
