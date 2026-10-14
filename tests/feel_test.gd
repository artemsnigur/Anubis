extends Node
## Feel measurement harness (numbers for FEEL_REPORT.md).
## Drives the hero in the test arena through simulated device input - Input.action_press,
## the same path a keyboard / gamepad takes - and reads the FeelProbe measurements.
## Lockouts and cancel windows are measured empirically: the follow-up input is mashed
## (pressed every other frame) and the frame it actually executes is recorded.
## godot --headless res://tests/feel_test.tscn                      measure + check the targets
## godot --headless res://tests/feel_test.tscn -- --measure-only     measure only (the "Before" table)
## Add `--report=<path>` to also write the Markdown table to a file.

const RUN_FRAMES := 70

var arena: Level
var player: Player
var dummy: EnemyBase
var rows: PackedStringArray = []
var _failures: int = 0
var _strict: bool = true
var _late: Array[Callable] = []
var _entries: Array = []   # [frame, state]
var _attack_index: Array = []   # [frame, index] of every Attack entry


func _ready() -> void:
	process_physics_priority = 2000
	get_tree().create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("feel_test: TIMEOUT")
		get_tree().quit(2))
	_strict = not OS.get_cmdline_user_args().has("--measure-only")
	arena = (load("res://scenes/levels/test_arena.tscn") as PackedScene).instantiate() as Level
	arena.set("spawn_dummies", false)
	add_child(arena)
	player = arena.player
	player.input.bot_enabled = false
	# Aim from the stick (none) -> attacks follow movement / facing, not the headless mouse.
	player.input.using_gamepad = true
	player.fsm.state_changed.connect(func(_f: StringName, to: StringName) -> void:
		_entries.append([Engine.get_physics_frames(), to])
		if to == &"Attack":
			_attack_index.append([Engine.get_physics_frames(), int(player.fsm.current.get("index"))]))
	_run.call_deferred()


## Runs queued input changes at the very end of the tick (after every gameplay node),
## so they become visible to the game at the start of the next tick - like a real device.
func _physics_process(_delta: float) -> void:
	for c in _late:
		c.call()
	_late.clear()


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


## Applies `fn` at the end of this tick; returns the frame in which the game first sees it.
func _input_late(fn: Callable) -> int:
	_late.append(fn)
	await get_tree().physics_frame
	return Engine.get_physics_frames()


func _press(action: StringName) -> int:
	var f := await _input_late(func() -> void: Input.action_press(action))
	_late.append(func() -> void: Input.action_release(action))
	return f


func _hold(action: StringName) -> int:
	return await _input_late(func() -> void: Input.action_press(action))


func _release_all() -> void:
	_late.append(func() -> void:
		for a: StringName in [&"move_left", &"move_right", &"move_up", &"move_down", &"attack_light", &"attack_heavy", &"dodge", &"heal", &"ranged"]:
			Input.action_release(a))
	await _frames(2)


func _reset(pos: Vector3 = Vector3(-2, 0.1, 6)) -> void:
	await _release_all()
	player.teleport_to(pos, 0.0)
	player.fsm.transition_to(&"Move")
	player.stamina = player.max_stamina
	await _frames(40)
	FeelProbe.results.clear()
	_entries.clear()
	_attack_index.clear()


## Mashes `action` (press every other frame) for `frames` frames; returns the first frame
## at or after `after` in which `state` was entered (or -1).
func _mash_until(action: StringName, state: StringName, after: int, frames: int, nth: int = 1) -> int:
	for i in frames:
		if i % 2 == 0:
			_late.append(func() -> void: Input.action_press(action))
		else:
			_late.append(func() -> void: Input.action_release(action))
		await get_tree().physics_frame
		var n := 0
		for e: Array in _entries:
			if int(e[0]) >= after and e[1] == state:
				n += 1
				if n >= nth:
					_late.append(func() -> void: Input.action_release(action))
					return int(e[0])
	_late.append(func() -> void: Input.action_release(action))
	return -1


func _first_entry(state: StringName, after: int, nth: int = 1) -> int:
	var n := 0
	for e: Array in _entries:
		if int(e[0]) >= after and e[1] == state:
			n += 1
			if n >= nth:
				return int(e[0])
	return -1


# --- table -------------------------------------------------------------------------------

func _row(metric: String, frames: int, target: String, lo: int, hi: int, duration: bool = false) -> void:
	var val := "n/a" if frames < 0 else ("%d f (%d ms)" % [frames, roundi(frames * 1000.0 / 60.0)] if duration else "%d f" % frames)
	var ok := frames >= lo and frames <= hi
	var mark := "" if lo < 0 else ("✅" if ok else "❌")
	rows.append("| %s | %s | %s | %s |" % [metric, val, target, mark])
	if lo >= 0 and not ok and _strict:
		_failures += 1
		print("FAIL ", metric, " = ", frames, " (target ", target, ")")


func _info(metric: String, value: String) -> void:
	rows.append("| %s | %s | – | |" % [metric, value])


func _check(cond: bool, msg: String) -> void:
	rows.append("| %s | %s | yes | %s |" % [msg, "yes" if cond else "NO", "✅" if cond else "❌"])
	if not cond and _strict:
		_failures += 1
		print("FAIL ", msg)


func _r(key: String) -> int:
	return int(FeelProbe.results.get(key, -1))


# --- trials --------------------------------------------------------------------------------

func _run() -> void:
	await _frames(30)
	var cam := arena.camera
	# Movement: start, run, stop, reverse.
	await _reset()
	var f0 := await _hold(&"move_right")
	var cam_start := cam.get_focus_position()
	var cam_moved := -1
	var max_off := 0.0
	var feet: Array = _feet()
	var prev_feet: Array = []
	var foot_min := [INF, INF]
	var slide: Array[float] = []
	for i in RUN_FRAMES:
		await get_tree().physics_frame
		if cam_moved < 0 and cam.get_focus_position().distance_to(cam_start) > 0.002:
			cam_moved = Engine.get_physics_frames() - f0
		if i < 30:
			var off := player.global_position + Vector3.UP * cam.target_height - cam.get_focus_position()
			off.y = 0.0
			max_off = maxf(max_off, off.length())
		# Foot sliding: lowest world speed of each foot per step (a planted foot should stop).
		if not feet.is_empty() and i >= 30:
			var now := [(feet[0] as Node3D).global_position, (feet[1] as Node3D).global_position]
			if not prev_feet.is_empty():
				for k in 2:
					var d: Vector3 = now[k] - prev_feet[k]
					d.y = 0.0
					foot_min[k] = minf(foot_min[k], d.length() * 60.0)
					if (i - 30) % 20 == 19:
						slide.append(foot_min[k])
						foot_min[k] = INF
			prev_feet = now
	var run_dir := player.velocity.normalized()
	var lag := (player.get_global_transform_interpolated().origin + Vector3.UP * cam.target_height - cam.get_focus_position())
	lag.y = 0.0
	_row("Input → first velocity change", _r("move_vel"), "same frame (0)", 0, 0)
	_row("Input → first visible pose change", _r("move_pose"), "≤ 1 f", 0, 1)
	_row("Idle → 90 % of top speed", _r("move_t90"), "0.08–0.12 s (5–7 f)", 5, 7, true)
	await _input_late(func() -> void: Input.action_release(&"move_right"))
	var settle := -1
	var last_focus := cam.get_focus_position()
	for i in 120:
		await get_tree().physics_frame
		var fp := cam.get_focus_position()
		if settle < 0 and i > 2 and fp.distance_to(last_focus) * 60.0 < 0.1:
			settle = i + 1
		last_focus = fp
	_row("Top speed → full stop", _r("stop"), "0.06–0.10 s (4–6 f)", 4, 6, true)
	await _hold(&"move_right")
	await _frames(RUN_FRAMES)
	await _input_late(func() -> void:
		Input.action_release(&"move_right")
		Input.action_press(&"move_left"))
	await _frames(30)
	_row("180° turn (facing ≤ 10° and ≥ 50 % speed the new way)", _r("turn"), "≤ 0.10 s (≤ 6 f)", 0, 6, true)
	_info("  ↳ facing within 10°", "%d f" % _r("turn_face"))
	_info("  ↳ velocity ≥ 50 % in the new direction", "%d f" % _r("turn_vel"))
	await _release_all()
	_info("Camera: input → camera starts moving", "%d f" % cam_moved)
	_info("Camera: hero's largest distance from screen centre in the first 0.5 s of a run", "%.2f m" % max_off)
	_info("Camera: still drifting after the hero stopped for", "%d f (%d ms)" % [settle, roundi(settle * 1000.0 / 60.0)])
	var avg := 0.0
	for v in slide:
		avg += v
	_info("Foot sliding at full run: planted-foot speed (0 = locked)", "%.2f m/s" % (avg / maxf(slide.size(), 1.0)) if not slide.is_empty() else "n/a")
	_info("Camera: offset player ↔ screen centre at full run (+ = player behind centre)", "%.2f m" % lag.dot(-run_dir))

	# Light attack.
	await _reset()
	f0 = await _press(&"attack_light")
	await _frames(40)
	_row("Light: input → first anticipation (state + pose)", _r("attack_light_pose"), "same frame (0)", 0, 0)
	_row("Light: input → first active hitbox frame", _r("attack_light_active"), "6–8 f", 6, 8)
	await _reset()
	f0 = await _press(&"attack_light")
	var dodge_at := await _mash_until(&"dodge", &"Dodge", f0, 50)
	var light_dodge := dodge_at - f0 if dodge_at >= 0 else 999
	_row("Light: input → dodge-cancel (dodge mashed)", dodge_at - f0 if dodge_at >= 0 else -1, "≤ 12 f", 0, 12)
	await _reset()
	f0 = await _press(&"attack_light")
	var chain_at := await _mash_until(&"attack_light", &"Attack", f0, 50, 2)
	var light_chain := chain_at - f0 if chain_at >= 0 else 999
	_info("Light: input → next attack of the chain (attack mashed)", "%d f" % (chain_at - f0 if chain_at >= 0 else -1))
	await _reset()
	f0 = await _press(&"attack_light")
	await _hold(&"move_down")
	var move_at := -1
	for i in 60:
		await get_tree().physics_frame
		if player.fsm.is_in(&"Move"):
			move_at = Engine.get_physics_frames() - f0
			break
	_info("Light: input → movement accepted (move held)", "%d f" % move_at)
	var lock := mini(mini(light_dodge, light_chain), move_at if move_at >= 0 else 999)
	_info("Light: total lockout (frames until any of move / attack / dodge is accepted)", "%d f" % lock)
	# Full 3-hit chain, attack mashed: when does each hit start?
	await _reset()
	f0 = await _press(&"attack_light")
	await _mash_until(&"attack_light", &"Attack", f0, 80, 3)
	await _frames(30)
	var starts: PackedStringArray = []
	for e: Array in _attack_index:
		starts.append("%d" % (int(e[0]) - f0))
	_info("Light chain rhythm: hit 1 / 2 / 3 start at frame", " / ".join(starts))

	# Heavy (tap).
	await _reset()
	f0 = await _press(&"attack_heavy")
	await _frames(60)
	_info("Heavy (tap): input → anticipation", "%d f" % _r("attack_heavy_pose"))
	_info("Heavy (tap): input → active hitbox", "%d f" % _r("attack_heavy_active"))
	await _reset()
	f0 = await _press(&"attack_heavy")
	dodge_at = await _mash_until(&"dodge", &"Dodge", f0, 80)
	_info("Heavy: input → dodge-cancel (dodge mashed)", "%d f" % (dodge_at - f0 if dodge_at >= 0 else -1))

	# Dodge.
	await _reset()
	f0 = await _press(&"dodge")
	await _frames(40)
	_row("Dodge: input → movement", _r("dodge_move"), "same frame (0)", 0, 0)
	_row("Dodge: input → first i-frame", _r("dodge_iframe"), "≤ 2 f", 0, 2)
	_info("Dodge: i-frame window", "%d f" % _r("dodge_iframe_len"))
	await _reset()
	f0 = await _press(&"dodge")
	var att := await _mash_until(&"attack_light", &"Attack", f0, 50)
	_info("Dodge: input → attack accepted (attack mashed)", "%d f" % (att - f0 if att >= 0 else -1))
	await _reset()
	f0 = await _press(&"dodge")
	await _hold(&"move_down")
	move_at = -1
	for i in 60:
		await get_tree().physics_frame
		if player.fsm.is_in(&"Move"):
			move_at = Engine.get_physics_frames() - f0
			break
	_info("Dodge: input → movement accepted (move held)", "%d f" % move_at)

	# Crossfades (AnimationTree transition times).
	_row("Crossfade locomotion → light_1", FeelProbe.xfade_frames(&"locomotion", &"light_1"), "0–3 f", 0, 3)
	_row("Crossfade light_1 → light_2", FeelProbe.xfade_frames(&"light_1", &"light_2"), "0–3 f", 0, 3)
	_row("Crossfade locomotion → dodge", FeelProbe.xfade_frames(&"locomotion", &"dodge"), "0–3 f", 0, 3)
	_row("Crossfade light_1 → locomotion", FeelProbe.xfade_frames(&"light_1", &"locomotion"), "≤ 6 f", 0, 6)
	_info("Locomotion idle ↔ walk ↔ run", "BlendSpace1D driven by speed every frame (no crossfade)")

	# Hitstop and buffered input against a training dummy.
	dummy = (load("res://scenes/enemies/training_dummy.tscn") as PackedScene).instantiate() as EnemyBase
	arena.add_child(dummy)
	dummy.global_position = Vector3(0, 0, 0)
	await _frames(10)
	await _face_dummy()
	f0 = await _press(&"attack_light")
	await _frames(40)
	_info("Light hit: hitstop on the hero", "%d f (%d ms)" % [_r("hitstop_player"), roundi(_r("hitstop_player") * 1000.0 / 60.0)])
	_info("Light hit: hitstop on the target", "%d f (%d ms)" % [_r("hitstop_target"), roundi(_r("hitstop_target") * 1000.0 / 60.0)])
	_info("Light hit: target reaction", "flinch=%s" % str(dummy.fsm.previous_name == &"Flinch" or dummy.fsm.is_in(&"Flinch")))
	# A single dodge press during the hero's hitstop must execute.
	await _face_dummy()
	f0 = await _press(&"attack_light")
	var hs_press := -1
	for i in 30:
		await get_tree().physics_frame
		if player.hitstop_left > 0.0:
			hs_press = await _press(&"dodge")
			break
	await _frames(40)
	var d_at := _first_entry(&"Dodge", f0)
	_check(hs_press >= 0 and d_at >= 0, "Dodge pressed once during hitstop is executed")
	_info("  ↳ dodge press (in hitstop) → dodge starts", "%d f" % (d_at - hs_press if d_at >= 0 and hs_press >= 0 else -1))
	# A single attack press during the hitstop must chain.
	await _face_dummy()
	f0 = await _press(&"attack_light")
	hs_press = -1
	for i in 30:
		await get_tree().physics_frame
		if player.hitstop_left > 0.0:
			hs_press = await _press(&"attack_light")
			break
	await _frames(50)
	var second := _first_entry(&"Attack", f0 + 1)
	_check(hs_press >= 0 and second >= 0, "Attack pressed once during hitstop chains into the next hit")
	_info("  ↳ attack press (in hitstop) → next hit starts", "%d f" % (second - hs_press if second >= 0 and hs_press >= 0 else -1))

	_info("Physics interpolation", str(ProjectSettings.get_setting("physics/common/physics_interpolation")))
	_info("Physics ticks per second", str(Engine.physics_ticks_per_second))
	var header := "| Metric | Measured | Target | |\n|---|---|---|---|"
	var table := header + "\n" + "\n".join(rows)
	print(table)
	for a: String in OS.get_cmdline_user_args():
		if a.begins_with("--report="):
			var fa := FileAccess.open(a.substr(9), FileAccess.WRITE)
			if fa != null:
				fa.store_string(table + "\n")
	print("feel_test: %d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


## Right / left foot nodes of a placeholder rig (empty for other rigs).
func _feet() -> Array:
	var rig := player.rig as PlaceholderRig
	if rig == null or not rig.bones.has("FootR"):
		return []
	return [rig.bones["FootR"], rig.bones["FootL"]]


## Puts the hero 1.8 m in front of the dummy, facing it, with a fresh dummy.
func _face_dummy() -> void:
	await _release_all()
	dummy.health.revive_full()
	dummy.poise.restore()
	dummy.fsm.transition_to(&"Idle")
	player.teleport_to(Vector3(0, 0.1, 1.8), 0.0)
	player.fsm.transition_to(&"Move")
	await _frames(30)
	FeelProbe.results.clear()
	_entries.clear()
	_attack_index.clear()
