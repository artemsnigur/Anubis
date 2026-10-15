extends Node
## F6 / F7 feel presets: F7 (a real key event) cycles Old -> Snappy -> Weighty and the hero
## picks up each preset (crossfades, camera, movement numbers); F6 opens the tuning panel
## and editing a value there changes the live preset. Restores the user's saved preset.
## godot --headless res://tests/preset_test.tscn

var arena: Level
var player: Player
var _failures: int = 0
var _saved_preset: String
var _late: Array[Callable] = []


func _ready() -> void:
	process_physics_priority = 2000
	get_tree().create_timer(120.0, true, false, true).timeout.connect(func() -> void:
		print("preset_test: TIMEOUT")
		get_tree().quit(2))
	_saved_preset = Settings.feel_preset
	GameState.set_feel_preset(&"old", false)
	arena = (load("res://scenes/levels/test_arena.tscn") as PackedScene).instantiate() as Level
	arena.set("spawn_dummies", false)
	add_child(arena)
	player = arena.player
	player.input.using_gamepad = true
	_run.call_deferred()


func _physics_process(_delta: float) -> void:
	for c in _late:
		c.call()
	_late.clear()


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_failures += 1


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _key(code: Key) -> void:
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.physical_keycode = code
		ev.keycode = code
		ev.pressed = pressed
		Input.parse_input_event(ev)
		await _frames(2)


## Runs right from a standstill and returns FeelProbe's 0 -> 90 % ticks.
func _t90() -> int:
	player.teleport_to(Vector3(-6, 0.1, 9), 0.0)
	await _frames(20)
	FeelProbe.results.erase("move_t90")
	_late.append(func() -> void: Input.action_press(&"move_right"))
	await _frames(40)
	_late.append(func() -> void: Input.action_release(&"move_right"))
	await _frames(20)
	return int(FeelProbe.results.get("move_t90", -1))


func _run() -> void:
	await _frames(20)
	var seen: Dictionary = {}
	for i in 3:
		await _key(KEY_F7)
		var f := GameState.feel
		seen[f.id] = await _t90()
		_check(player.feel == f, "F7 -> %s: the hero uses the new preset" % f.display_name)
		_check(FeelProbe.xfade_frames(&"locomotion", &"light_1") == roundi(f.combat_xfade * 60.0), "%s: combat crossfade %d f" % [f.display_name, roundi(f.combat_xfade * 60.0)])
		_check(Settings.feel_preset == String(f.id), "%s: choice stored in the settings" % f.display_name)
	_check(seen.size() == 3, "F7 visits all three presets (%s)" % str(seen.keys()))
	_check(int(seen.get(&"snappy", -1)) < int(seen.get(&"weighty", -1)), "Snappy reaches top speed sooner than Weighty (%s)" % str(seen))
	# F6 tuning panel: open it, edit camera_follow through its SpinBox.
	await _key(KEY_F6)
	var panel := DebugOverlay.get("_tuning") as TuningPanel
	_check(panel != null and panel.visible, "F6 opens the tuning panel")
	var spin: SpinBox = null
	if panel != null:
		for sb in panel.find_children("*", "SpinBox", true, false):
			var row := sb.get_parent()
			if (row.get_child(0) as Label).text == "camera follow":
				spin = sb as SpinBox
	_check(spin != null, "panel has a row for camera_follow")
	if spin != null:
		spin.value = 21.5
		await _frames(2)
		_check(is_equal_approx(GameState.feel.camera_follow, 21.5), "editing the panel changes the live preset (%.1f)" % GameState.feel.camera_follow)
	GameState.reload_feel_preset()
	_check(not is_equal_approx(GameState.feel.camera_follow, 21.5), "Reload restores the preset from disk")
	await _key(KEY_F6)
	_check(panel != null and not panel.visible, "F6 closes the panel")
	GameState.set_feel_preset(StringName(_saved_preset), true)
	print("preset_test: %d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
