extends Node
## Title screen flow: New Game and Continue must load the Necropolis (not the test arena),
## Continue must place the player at the saved altar; Training Arena opens the feel arena
## as a sandbox (resting there never overwrites the save) and F8 spawns sparring enemies.
## godot --headless res://tests/menu_flow_test.tscn

var _failures: int = 0


## The test scene itself is replaced by change_scene, so the logic runs in a copy of
## this node parked under the root window (outside the current scene).
var is_runner: bool = false


func _ready() -> void:
	GameState.set_feel_preset(GameState.DEFAULT_FEEL, false)
	if not is_runner:
		var runner: Node = (get_script() as GDScript).new()
		runner.set(&"is_runner", true)
		runner.name = "MenuFlowRunner"
		get_tree().root.add_child.call_deferred(runner)
		return
	get_tree().create_timer(60.0, true, false, true).timeout.connect(func() -> void:
		print("menu_flow_test: TIMEOUT")
		get_tree().quit(2))
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _run() -> void:
	SaveSystem.delete_save()
	GameState.reset_progress()
	# New Game from the title screen.
	get_tree().change_scene_to_file("res://scenes/ui/title_menu.tscn")
	await _wait(1.5)
	var title := get_tree().current_scene
	_check(title != null and title.scene_file_path == "res://scenes/ui/title_menu.tscn", "title screen loads")
	title.call(&"_on_new_game")
	await _wait(3.0)
	var scene := get_tree().current_scene
	_check(scene != null and scene.scene_file_path == "res://scenes/levels/necropolis.tscn", "New Game loads the Necropolis (got %s)" % (scene.scene_file_path if scene != null else "null"))
	var lv := scene as Level
	_check(lv != null and lv.player.global_position.distance_to(lv.start_position) < 1.5, "player starts at the courtyard start")
	# Continue: save at the second altar, go back to the title, continue.
	GameState.last_altar = &"judgement"
	SaveSystem.save_game()
	get_tree().change_scene_to_file("res://scenes/ui/title_menu.tscn")
	await _wait(1.5)
	get_tree().current_scene.call(&"_on_continue")
	# Poll instead of a fixed wait: under load the fade + scene load can take longer.
	lv = null
	for i in 80:
		await _wait(0.1)
		lv = get_tree().current_scene as Level
		if lv != null and lv.scene_file_path == "res://scenes/levels/necropolis.tscn" and lv.player != null and lv.is_node_ready():
			break
	_check(lv != null and lv.scene_file_path == "res://scenes/levels/necropolis.tscn", "Continue loads the Necropolis")
	if lv != null:
		var altar := lv.altars[&"judgement"] as Altar
		var d := lv.player.global_position.distance_to(altar.spawn_point())
		_check(d < 1.5, "Continue places the player at the saved altar (%.1f m away)" % d)
	# Training Arena: sandbox, the real save stays untouched.
	var before := FileAccess.get_file_as_string(SaveSystem.SAVE_PATH)
	get_tree().change_scene_to_file("res://scenes/ui/title_menu.tscn")
	await _wait(1.5)
	_check(not GameState.sandbox, "title screen leaves sandbox mode")
	get_tree().current_scene.call(&"_on_arena")
	await _wait(3.0)
	lv = get_tree().current_scene as Level
	_check(lv != null and lv.scene_file_path == "res://scenes/levels/test_arena.tscn", "Training Arena opens the test arena")
	_check(GameState.sandbox and not SaveSystem.save_game(), "arena is a sandbox (save_game writes nothing)")
	_check(FileAccess.get_file_as_string(SaveSystem.SAVE_PATH) == before, "the real save file is unchanged")
	if lv != null:
		var ev := InputEventKey.new()
		ev.physical_keycode = KEY_F8
		ev.pressed = true
		Input.parse_input_event(ev)
		await _wait(0.2)
		var up := InputEventKey.new()
		up.physical_keycode = KEY_F8
		Input.parse_input_event(up)
		await _wait(0.3)
		var found: EnemyBase = null
		for n in get_tree().get_nodes_in_group(&"enemies"):
			if n is EnemyBase and not (n is TrainingDummy):
				found = n as EnemyBase
		_check(found != null and found.aware, "F8 spawns an aware sparring enemy (%s)" % (String(found.name) if found != null else "none"))
	SaveSystem.delete_save()
	print("menu_flow_test: %d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
