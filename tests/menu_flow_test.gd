extends Node
## Title screen flow: New Game and Continue must load the Necropolis (not the test arena),
## Continue must place the player at the saved altar.
## godot --headless res://tests/menu_flow_test.tscn

var _failures: int = 0


## The test scene itself is replaced by change_scene, so the logic runs in a copy of
## this node parked under the root window (outside the current scene).
var is_runner: bool = false


func _ready() -> void:
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
	await _wait(3.0)
	lv = get_tree().current_scene as Level
	_check(lv != null and lv.scene_file_path == "res://scenes/levels/necropolis.tscn", "Continue loads the Necropolis")
	if lv != null:
		var altar := lv.altars[&"judgement"] as Altar
		_check(lv.player.global_position.distance_to(altar.spawn_point()) < 1.5, "Continue places the player at the saved altar")
	SaveSystem.delete_save()
	print("menu_flow_test: %d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
