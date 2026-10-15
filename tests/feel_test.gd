extends Node
## Feel measurement harness (numbers for FEEL_REPORT.md).
## Drives the hero in the test arena through simulated device input - Input.action_press,
## the same path a keyboard / gamepad takes - and reads the FeelProbe measurements.
## Lockouts and cancel windows are measured empirically: the follow-up input is mashed
## (pressed every other frame) and the frame it actually executes is recorded.
## godot --headless res://tests/feel_test.tscn                      measure + check the targets
## godot --headless res://tests/feel_test.tscn -- --measure-only     measure only (the "Before" table)
## Add `--preset=grounded|snappy|old` to measure another feel preset (default: grounded).
## Add `--report=<path>` to also write the Markdown table to a file.

const RUN_FRAMES := 100

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
	# Feel preset under test (default: the shipped default), never persisted. The harness
	# also runs on the pre-feel-pass commit (no presets) for the "Before" table.
	if GameState.has_method(&"set_feel_preset"):
		var preset: StringName = GameState.get(&"DEFAULT_FEEL")
		for a: String in OS.get_cmdline_user_args():
			if a.begins_with("--preset="):
				preset = StringName(a.substr(9))
		GameState.call(&"set_feel_preset", preset, false)
		print("feel_test: preset ", _feel(&"display_name", ""))
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


## Row whose target comes from the preset under test (FeelProbe.TARGETS_BY_PRESET).
func _rowk(metric: String, frames: int, key: String, duration: bool = false) -> void:
	var t := FeelProbe.targets()
	if not t.has(key):
		_row(metric, frames, "–", -1, -1, duration)
		return
	var lo := int(t[key][0])
	var hi := int(t[key][1])
	var text := ("= %d f" % lo) if lo == hi else ("%d–%d f" % [lo, hi])
	if duration:
		text += " (%d–%d ms)" % [roundi(lo * 1000.0 / 60.0), roundi(hi * 1000.0 / 60.0)]
	_row(metric, frames, text, lo, hi, duration)


func _info(metric: String, value: String) -> void:
	rows.append("| %s | %s | – | |" % [metric, value])


func _check(cond: bool, msg: String) -> void:
	rows.append("| %s | %s | yes | %s |" % [msg, "yes" if cond else "NO", "✅" if cond else "❌"])
	if not cond and _strict:
		_failures += 1
		print("FAIL ", msg)


## A value of the active FeelPreset (or `fallback` on code without presets).
func _feel(key: StringName, fallback: Variant) -> Variant:
	var f: Variant = GameState.get(&"feel")
	return (f as Resource).get(key) if f != null else fallback


## Frame (0 = input frame) on which a window opening at state time `t` is first open:
## the state's first update runs in the input tick with time = 1 tick.
func _open_frame(t: float) -> int:
	return maxi(ceili(t * 60.0 - 0.001) - 1, 0)


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
		if i >= 40:
			# Lag of the camera behind where it wants to be (hero + look-ahead).
			var want := player.get_global_transform_interpolated().origin + Vector3.UP * cam.target_height + (cam.get("_look_ahead") as Vector3)
			var off := want - cam.get_focus_position()
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
					if (i - 30) % 30 == 29:
						slide.append(foot_min[k])
						foot_min[k] = INF
			prev_feet = now
	var run_dir := player.velocity.normalized()
	var lag := (player.get_global_transform_interpolated().origin + Vector3.UP * cam.target_height - cam.get_focus_position())
	lag.y = 0.0
	_rowk("Input → first velocity change", _r("move_vel"), "move_vel")
	_rowk("Input → first visible pose change", _r("move_pose"), "move_pose")
	_rowk("Idle → 90 % of top speed", _r("move_t90"), "move_t90", true)
	await _input_late(func() -> void: Input.action_release(&"move_right"))
	# Camera after the stop: first frame from which it stays still (< 0.1 m/s) for 10 frames.
	var settle := -1
	var still := 0
	var last_focus := cam.get_focus_position()
	for i in 120:
		await get_tree().physics_frame
		var fp := cam.get_focus_position()
		if fp.distance_to(last_focus) * 60.0 < 0.1:
			still += 1
			if still >= 10 and settle < 0:
				settle = i + 1 - 9
		else:
			still = 0
		last_focus = fp
	_rowk("Top speed → full stop", _r("stop"), "stop", true)
	await _reset(Vector3(-6, 0.1, 9))
	await _hold(&"move_right")
	await _frames(60)
	await _input_late(func() -> void:
		Input.action_release(&"move_right")
		Input.action_press(&"move_left"))
	await _frames(70)
	_rowk("180° turn (facing ≤ 10° and ≥ 50 % speed the new way)", _r("turn"), "turn", true)
	_info("  ↳ facing within 10°", "%d f" % _r("turn_face"))
	_info("  ↳ velocity ≥ 50 % in the new direction", "%d f" % _r("turn_vel"))
	await _release_all()
	_info("Camera: input → camera starts moving", "%d f" % cam_moved)
	_info("Camera: lag behind its target (hero + look-ahead) at full run", "%.2f m" % max_off)
	_info("Camera: comes to rest after the hero stops (still for 10 f)", "%d f (%d ms)" % [settle, roundi(settle * 1000.0 / 60.0)])
	var avg := 0.0
	for v in slide:
		avg += v
	_info("Foot sliding at full run: planted-foot speed (0 = locked)", "%.2f m/s" % (avg / maxf(slide.size(), 1.0)) if not slide.is_empty() else "n/a")
	_info("Camera: offset player ↔ screen centre at full run (+ = player behind centre)", "%.2f m" % lag.dot(-run_dir))

	# Light attack.
	await _reset()
	f0 = await _press(&"attack_light")
	await _frames(40)
	_rowk("Light: input → first anticipation (state + pose)", _r("attack_light_pose"), "attack_light_pose")
	_rowk("Light: input → first active hitbox frame", _r("attack_light_active"), "attack_light_active")
	await _reset()
	f0 = await _press(&"attack_light")
	var dodge_at := await _mash_until(&"dodge", &"Dodge", f0, 50)
	var light_dodge := dodge_at - f0 if dodge_at >= 0 else 999
	_rowk("Light: input → dodge-cancel (dodge mashed)", dodge_at - f0 if dodge_at >= 0 else -1, "light_dodge_cancel")
	await _reset()
	f0 = await _press(&"attack_light")
	var chain_at := await _mash_until(&"attack_light", &"Attack", f0, 50, 2)
	var light_chain := chain_at - f0 if chain_at >= 0 else 999
	_info("Light: input → next attack of the chain (attack mashed)", "%d f" % (chain_at - f0 if chain_at >= 0 else -1))
	await _reset()
	f0 = await _press(&"attack_light")
	await _hold(&"move_down")
	await _frames(60)
	var move_at := _first_entry(&"Move", f0)
	move_at = move_at - f0 if move_at >= 0 else -1
	_info("Light: input → movement accepted (move held)", "%d f" % move_at)
	var l1: AttackData = player.stats.light_attacks[0]
	if _strict:
		_row("  ↳ dodge window opens on its frame (w+a+cancel_delay)", light_dodge, "= %d f" % _open_frame(l1.windup + l1.active + l1.cancel_delay), _open_frame(l1.windup + l1.active + l1.cancel_delay), _open_frame(l1.windup + l1.active + l1.cancel_delay))
		_row("  ↳ chain window opens on its frame (w+a+chain_delay)", light_chain, "= %d f" % _open_frame(l1.windup + l1.active + l1.chain_delay), _open_frame(l1.windup + l1.active + l1.chain_delay), _open_frame(l1.windup + l1.active + l1.chain_delay))
		var mv := _open_frame(l1.windup + l1.active + l1.recovery * float(_feel(&"walk_out_recovery", 0.7)))
		_row("  ↳ walk-out window opens on its frame", move_at, "= %d f" % mv, mv, mv)
	# One buffered dodge press, 6 frames before the window: must fire on the first legal frame.
	await _reset()
	f0 = await _press(&"attack_light")
	var open_at := f0 + _open_frame(l1.windup + l1.active + l1.cancel_delay)
	while Engine.get_physics_frames() < open_at - 7:
		await get_tree().physics_frame
	await _press(&"dodge")
	await _frames(20)
	var single := _first_entry(&"Dodge", f0)
	_row("Buffered dodge (pressed 6 f early) fires on the first legal frame", single - f0 if single >= 0 else -1,
		"= %d f" % (open_at - f0), open_at - f0 if _strict else -1, open_at - f0)
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

	# One attack press early in the swing (2nd frame of the windup) must still chain.
	await _reset()
	f0 = await _press(&"attack_light")
	await _frames(1)
	await _press(&"attack_light")
	await _frames(40)
	var early := _first_entry(&"Attack", f0, 2)
	_check(early >= 0, "Attack pressed once early in the windup chains into hit 2")
	_info("  ↳ hit 2 starts at frame", "%d f" % (early - f0 if early >= 0 else -1))

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
	_rowk("Dodge: input → movement", _r("dodge_move"), "dodge_move")
	_rowk("Dodge: input → first i-frame", _r("dodge_iframe"), "dodge_iframe")
	var expect_len := 0
	for k in 60:
		var t := (k + 1) / 60.0
		if t >= float(_feel(&"iframe_start", 0.05)) - 0.0001 and t < float(_feel(&"iframe_end", 0.25)) - 0.0001:
			expect_len += 1
	_row("Dodge: i-frame window length", _r("dodge_iframe_len"), "= %d f (preset)" % expect_len, expect_len if _strict else -1, expect_len)
	await _reset()
	f0 = await _press(&"dodge")
	var att := await _mash_until(&"attack_light", &"Attack", f0, 50)
	var exp_att := _open_frame(float(_feel(&"dodge_attack_cancel", 0.25)))
	_row("Dodge: input → attack accepted (attack mashed)", att - f0 if att >= 0 else -1, "= %d f (preset)" % exp_att, exp_att if _strict else -1, exp_att)
	await _reset()
	f0 = await _press(&"dodge")
	await _hold(&"move_down")
	await _frames(60)
	move_at = _first_entry(&"Move", f0)
	move_at = move_at - f0 if move_at >= 0 else -1
	var exp_mv := _open_frame(float(_feel(&"dodge_move_cancel", 0.35)))
	_row("Dodge: input → movement accepted (move held)", move_at, "= %d f (preset)" % exp_mv, exp_mv if _strict else -1, exp_mv)

	# Crossfades (AnimationTree transition times).
	_rowk("Crossfade locomotion → light_1", FeelProbe.xfade_frames(&"locomotion", &"light_1"), "xfade_combat")
	_rowk("Crossfade light_1 → light_2", FeelProbe.xfade_frames(&"light_1", &"light_2"), "xfade_combat")
	_rowk("Crossfade locomotion → dodge", FeelProbe.xfade_frames(&"locomotion", &"dodge"), "xfade_combat")
	_rowk("Crossfade light_1 → locomotion", FeelProbe.xfade_frames(&"light_1", &"locomotion"), "xfade_loco")
	_info("Locomotion idle ↔ walk ↔ run", "BlendSpace1D driven by speed every frame (no crossfade)")

	# Hitstop and buffered input against a training dummy.
	dummy = (load("res://scenes/enemies/training_dummy.tscn") as PackedScene).instantiate() as EnemyBase
	arena.add_child(dummy)
	dummy.global_position = Vector3(0, 0, 0)
	await _frames(10)
	await _face_dummy()
	f0 = await _press(&"attack_light")
	await _frames(40)
	_rowk("Light hit: hitstop on the hero", _r("hitstop_player"), "hitstop_player", true)
	_rowk("Light hit: hitstop on the target", _r("hitstop_target"), "hitstop_target", true)
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
	var second := _first_entry(&"Attack", f0, 2)
	_check(hs_press >= 0 and second >= 0, "Attack pressed once during hitstop chains into the next hit")
	_info("  ↳ attack press (in hitstop) → next hit starts", "%d f" % (second - hs_press if second >= 0 and hs_press >= 0 else -1))

	await _alive_checks()
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
	dummy.teleport_to(Vector3.ZERO, 0.0)
	player.teleport_to(Vector3(0, 0.1, 1.8), 0.0)
	player.fsm.transition_to(&"Move")
	await _frames(30)
	FeelProbe.results.clear()
	_entries.clear()
	_attack_index.clear()


## Procedural "alive" layers (only meaningful when the preset enables them).
func _alive_checks() -> void:
	var rig := player.rig as PlaceholderRig
	if rig == null or float(_feel(&"secondary_motion", 0.0)) <= 0.0 or not player.has_signal(&"footstep_side"):
		_info("Alive layers", "off in this preset")
		return
	dummy.teleport_to(Vector3(30, 0, 30), 0.0)
	await _reset(Vector3(-6, 0.1, 9))
	var flap := rig.bones["KiltFlap"] as Node3D
	var rest := flap.basis
	var steps: Array = []
	player.connect(&"footstep_side", func(side: StringName) -> void: steps.append(side))
	await _hold(&"move_right")
	var max_swing := 0.0
	for i in 60:
		await get_tree().physics_frame
		max_swing = maxf(max_swing, rad_to_deg(flap.basis.get_rotation_quaternion().angle_to(rest.get_rotation_quaternion())))
	await _release_all()
	await _frames(150)
	var settle := rad_to_deg(flap.basis.get_rotation_quaternion().angle_to(rest.get_rotation_quaternion()))
	_check(max_swing > 8.0 and settle < 3.0, "Secondary motion: kilt panel swings at a run (%.0f°) and settles at rest (%.1f°)" % [max_swing, settle])
	_check(steps.has(&"r") and steps.has(&"l"), "Footstep events report the planted foot (%d steps)" % steps.size())
	# Additive layers must not accumulate while the animation is frozen by hitstop.
	var chest := rig.bones["Chest"] as Node3D
	player.apply_hitstop(1.0)
	await _frames(2)
	var q0 := chest.quaternion
	await _frames(50)
	var drift := rad_to_deg(chest.quaternion.angle_to(q0))
	player.hitstop_left = 0.0
	_check(drift < 1.0, "No additive drift during a 1 s freeze (%.2f°)" % drift)
	# Look-at: an enemy to the hero's right turns the head toward it.
	dummy.teleport_to(player.global_position + player.global_basis.x * 3.0, 0.0)
	await _frames(40)
	var head := rig.bones["Head"] as Node3D
	var fwd := -head.global_basis.z
	var to := dummy.global_position - player.global_position
	var turned := rad_to_deg(Vector2(fwd.x, fwd.z).angle_to(Vector2(-player.global_basis.z.x, -player.global_basis.z.z)))
	_check(absf(turned) > 15.0 and fwd.dot(to) > (-player.global_basis.z).dot(to), "Head turns toward a nearby enemy (%.0f°)" % absf(turned))
