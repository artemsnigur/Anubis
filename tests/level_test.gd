extends Node
## Level verification: navmesh connectivity between all key points, interactables
## present, and a physical walk (player bot following the navmesh path with enemies
## removed) from the start to the boss arena, so nothing gets stuck in geometry.
## godot --headless res://tests/level_test.tscn

var level: Level
var player: Player
var _failures: int = 0
var _log: PackedStringArray = []


func _ready() -> void:
	GameState.set_feel_preset(GameState.DEFAULT_FEEL, false)
	# Watchdog: never hang a CI run.
	get_tree().create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("level_test: TIMEOUT")
		get_tree().quit(2))
	SaveSystem.delete_save()
	GameState.reset_progress()
	level = (load("res://scenes/levels/necropolis.tscn") as PackedScene).instantiate() as Level
	add_child(level)
	player = level.player
	player.input.bot_enabled = true
	player.god_mode = true
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	_log.append(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _path(from: Vector3, to: Vector3) -> PackedVector3Array:
	var map := player.get_world_3d().navigation_map
	var a := NavigationServer3D.map_get_closest_point(map, from)
	var b := NavigationServer3D.map_get_closest_point(map, to)
	return NavigationServer3D.map_get_path(map, a, b, true)


func _reachable(from: Vector3, to: Vector3, label: String) -> PackedVector3Array:
	var p := _path(from, to)
	var ok := p.size() > 1 and p[p.size() - 1].distance_to(to) < 2.0
	var length := 0.0
	for i in range(1, p.size()):
		length += p[i - 1].distance_to(p[i])
	_check(ok, "navmesh path: %s (%.0f m)" % [label, length])
	return p


func _run() -> void:
	await _wait(1.0)
	var start := level.start_position
	var courtyard_altar := (level.altars[&"courtyard"] as Altar).spawn_point()
	var judgement := (level.altars[&"judgement"] as Altar).spawn_point()
	var arena := Vector3(0, -4, -112)
	var shrine := Vector3(-28, -4, -55)
	var lever := Vector3(21.5, 0, 7.5)
	_reachable(start, courtyard_altar, "start -> courtyard altar")
	_reachable(start, shrine, "start -> canopic shrine (side room)")
	_reachable(start, lever, "start -> shortcut lever (through the gallery)")
	_reachable(start, judgement, "start -> second altar")
	var main_path := _reachable(start, arena, "start -> Hall of Two Truths")
	_check(level.altars.size() == 2, "two Altars of Osiris")
	_check(get_tree().get_nodes_in_group(&"traps").size() == 3, "three spike traps in the corridor")
	_check(level.get("shortcut_gate") != null and level.get("lever") != null, "shortcut gate + lever")
	_check(level.get("veil") != null, "sand veil before the arena")
	var spawners := get_tree().get_nodes_in_group(&"spawners")
	var total := 0
	for s in spawners:
		total += (s as EnemySpawner).count
	_check(total >= 18, "level populated (%d enemies in %d spawners)" % [total, spawners.size()])
	# Physical walk: remove enemies, follow the path waypoints with the player.
	for s in spawners:
		(s as EnemySpawner).despawn()
		(s as EnemySpawner).deferred = true
	for t in get_tree().get_nodes_in_group(&"traps"):
		(t as Node).process_mode = Node.PROCESS_MODE_DISABLED
	var ok := await _walk(main_path, 70.0)
	_check(ok, "player physically walks from the start to the arena (%.1f m from goal)" % player.global_position.distance_to(arena))
	# Shortcut loop: from the arena back up through the gallery to the lever.
	player.teleport_to(Vector3(0, -3.9, -55), 0.0)
	await _wait(0.3)
	var loop := _path(player.global_position, lever)
	var ok2 := await _walk(loop, 50.0)
	_check(ok2, "player walks the gallery loop to the lever (%.1f m from goal)" % player.global_position.distance_to(lever))
	# Pull the lever: the gate opens, the flag is saved and the navmesh shortcut appears.
	var lv := level.get("lever") as Lever
	player.refresh_interactable()
	await _wait(0.2)
	_check(player.interactable == lv, "lever is the interaction target")
	player.input.bot_press(&"interact")
	await _wait(3.5)
	_check(lv.pulled and (level.get("shortcut_gate") as Gate).is_open, "lever opens the shortcut gate")
	_check(GameState.get_flag(&"shortcut_open"), "shortcut flag stored")
	var short := _path(start, lever)
	var length := 0.0
	for k in range(1, short.size()):
		length += short[k - 1].distance_to(short[k])
	_check(length < 45.0, "navmesh rebaked: start -> lever now %.0f m through the gate" % length)
	for l in _log:
		print(l)
	print("level_test: %d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)


func _walk(path: PackedVector3Array, timeout: float) -> bool:
	var i := 1
	var t := 0.0
	var stuck_t := 0.0
	var last := player.global_position
	while i < path.size() and t < timeout:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		var target := path[i]
		var to := target - player.global_position
		to.y = 0.0
		if to.length() < 0.6:
			i += 1
			continue
		var cam := player.input.camera
		var dir := to.normalized()
		# Convert the world direction into the camera-relative move vector.
		var right := cam.global_basis.x
		right.y = 0.0
		right = right.normalized()
		var fwd := -cam.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		player.input.bot_move = Vector2(dir.dot(right), -dir.dot(fwd))
		stuck_t += dt
		if stuck_t > 1.0:
			if player.global_position.distance_to(last) < 0.3:
				print("level_test: stuck near ", player.global_position, " heading to ", target)
				player.input.bot_move = Vector2.ZERO
				return false
			last = player.global_position
			stuck_t = 0.0
	player.input.bot_move = Vector2.ZERO
	return i >= path.size()
