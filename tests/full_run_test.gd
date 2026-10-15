extends Node
## End-to-end playthrough with a bot (god mode, 2x speed): rest at the first altar,
## fight through the courtyard, tomb, Hall of Pillars, take the side-room reward,
## rest at the second altar, kill Ammit and leave through the exit gate.
## Fails if the bot gets stuck in geometry or a step times out.
## godot --headless res://tests/full_run_test.tscn

var level: Level
var player: Player
var _failures: int = 0
var _attack_t: float = 0.0
var _dodge_t: float = 0.0
var _damage_taken: float = 0.0
var _game_time: float = 0.0


func _ready() -> void:
	GameState.set_feel_preset(GameState.DEFAULT_FEEL, false)
	get_tree().create_timer(900.0, true, false, true).timeout.connect(func() -> void:
		print("full_run_test: TIMEOUT")
		get_tree().quit(2))
	SaveSystem.delete_save()
	GameState.reset_progress()
	level = (load("res://scenes/levels/necropolis.tscn") as PackedScene).instantiate() as Level
	add_child(level)
	player = level.player
	player.input.bot_enabled = true
	player.god_mode = true
	player.damaged.connect(func(h: HitInfo) -> void: _damage_taken += h.damage)
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_failures += 1


func _physics_process(delta: float) -> void:
	_game_time += delta


func _move_dir(dir: Vector3) -> void:
	var cam := player.input.camera
	var r := cam.global_basis.x
	r.y = 0.0
	var f := -cam.global_basis.z
	f.y = 0.0
	player.input.bot_move = Vector2(dir.dot(r.normalized()), -dir.dot(f.normalized())) if dir.length() > 0.01 else Vector2.ZERO


func _nearest_enemy(max_dist: float) -> EnemyBase:
	var best: EnemyBase = null
	var bd := max_dist
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var e := n as EnemyBase
		if e == null or e.is_dead or e.fsm.is_in(&"Dormant") or e is TrainingDummy:
			continue
		if absf(e.global_position.y - player.global_position.y) > 2.5:
			continue
		var d := e.global_position.distance_to(player.global_position)
		if d < bd and e.can_see_player():
			bd = d
			best = e
	return best


## Fights the nearest enemy for one frame. Returns false when nothing is in range.
func _fight_step(delta: float, radius: float) -> bool:
	var e := _nearest_enemy(radius)
	if e == null:
		return false
	var to := e.global_position - player.global_position
	to.y = 0.0
	var reach := 2.0 + e.body_radius
	_move_dir(to.normalized() if to.length() > reach else Vector3.ZERO)
	player.input.bot_aim = to.normalized()
	_attack_t -= delta
	_dodge_t -= delta
	if to.length() < reach + 1.0 and _attack_t <= 0.0:
		_attack_t = 0.3
		player.input.bot_press(&"ranged" if player.energy >= 1.0 and to.length() > 3.0 else &"attack_light")
	if _dodge_t <= 0.0 and e.fsm.is_in(&"Attack"):
		_dodge_t = 1.5
		player.input.bot_press(&"dodge")
	return true


## Walks to `goal` along the navmesh, fighting anything that shows up.
func _go(goal: Vector3, label: String, timeout: float = 120.0, fight_radius: float = 7.0) -> bool:
	var map := player.get_world_3d().navigation_map
	var t := 0.0
	var repath := 0.0
	var path := PackedVector3Array()
	var idx := 1
	var stuck_t := 0.0
	var last := player.global_position
	while t < timeout:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		if player.is_dead:
			continue
		if _fight_step(dt, fight_radius):
			stuck_t = 0.0
			last = player.global_position
			repath = 0.0
			continue
		var flat := Vector2(goal.x - player.global_position.x, goal.z - player.global_position.z)
		if flat.length() < 1.2 and absf(goal.y - player.global_position.y) < 2.0:
			_move_dir(Vector3.ZERO)
			return true
		repath -= dt
		if repath <= 0.0:
			repath = 1.0
			path = NavigationServer3D.map_get_path(map, NavigationServer3D.map_get_closest_point(map, player.global_position),
				NavigationServer3D.map_get_closest_point(map, goal), true)
			idx = 1
		while idx < path.size() and Vector2(path[idx].x - player.global_position.x, path[idx].z - player.global_position.z).length() < 0.7:
			idx += 1
		if idx < path.size():
			var d := path[idx] - player.global_position
			d.y = 0.0
			_move_dir(d.normalized())
		stuck_t += dt
		if stuck_t > 4.0:
			if player.global_position.distance_to(last) < 0.5:
				print("full_run_test: stuck at ", player.global_position, " going to ", label)
				return false
			last = player.global_position
			stuck_t = 0.0
	print("full_run_test: timeout going to ", label, " at ", player.global_position)
	return false


func _interact_with(node: Node3D, label: String) -> bool:
	player.refresh_interactable()
	await get_tree().create_timer(0.2).timeout
	if player.interactable != node:
		# Step closer and retry.
		await _go(node.global_position, label + " (closer)", 10.0, 0.0)
		player.refresh_interactable()
	player.input.bot_press(&"interact")
	await get_tree().create_timer(1.2).timeout
	return true


func _rest(altar: Altar) -> void:
	await _interact_with(altar, "altar")
	var tries := 0
	while not level.levelup.is_open and tries < 40:
		await get_tree().create_timer(0.1).timeout
		tries += 1
	_check(level.levelup.is_open, "rest at %s opens the level-up menu" % altar.altar_id)
	while GameState.can_level_up():
		level.levelup.call(&"_on_level", &"vitality" if GameState.total_level() % 2 == 0 else &"strength")
	level.levelup.close()
	await get_tree().create_timer(0.4).timeout


func _run() -> void:
	Engine.time_scale = 2.0
	await get_tree().create_timer(0.6).timeout
	var courtyard: Altar = level.altars[&"courtyard"]
	var judgement: Altar = level.altars[&"judgement"]
	var ok := await _go(courtyard.spawn_point(), "courtyard altar")
	_check(ok, "reached the first altar")
	await _rest(courtyard)
	_check(GameState.last_altar == &"courtyard", "first altar is the respawn point")
	for step: Array in [[Vector3(0, 0.1, 8), "courtyard fight"], [Vector3(0, -3.9, -18), "antechamber"], [Vector3(0, -3.9, -36), "trap corridor"],
		[Vector3(0, -3.9, -52), "Hall of Pillars"], [Vector3(-28, -3.9, -55), "side room"]]:
		Engine.time_scale = 2.0
		ok = await _go(step[0], step[1], 150.0)
		_check(ok, "reached: %s" % step[1])
		if not ok:
			break
	# Clear the side room and take the reward.
	await _go(Vector3(-27, -3.9, -55), "side room cleared", 60.0, 12.0)
	var shrine: RewardShrine = null
	for n in get_tree().get_nodes_in_group(&"level"):
		for c in (n as Node).find_children("*", "RewardShrine", true, false):
			shrine = c as RewardShrine
	if shrine != null:
		await _go(shrine.global_position + Vector3(1.6, 0, 0), "shrine", 30.0)
		await _interact_with(shrine, "shrine")
		await get_tree().create_timer(1.0).timeout
		_check(GameState.bonus_ankh == 1, "canopic shrine grants +1 Ankh charge")
	Engine.time_scale = 2.0
	ok = await _go(judgement.spawn_point(), "second altar", 180.0)
	_check(ok, "reached the second altar")
	await _rest(judgement)
	# Boss.
	Engine.time_scale = 2.0
	ok = await _go(Vector3(0, -3.9, -100), "arena", 60.0, 0.0)
	await get_tree().create_timer(1.0).timeout
	var arena := level.get("boss_arena") as BossArena
	_check(arena.fight_active, "boss fight started")
	var fight_t := 0.0
	while not GameState.get_flag(&"boss_defeated") and fight_t < 400.0:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		fight_t += dt
		if Engine.time_scale > 0.9 and Engine.time_scale < 1.9:
			Engine.time_scale = 2.0
		if not _fight_step(dt, 40.0):
			_move_dir(Vector3.ZERO)
	_check(GameState.get_flag(&"boss_defeated"), "Ammit defeated (%.0f s of fighting)" % fight_t)
	await get_tree().create_timer(5.0).timeout
	Engine.time_scale = 2.0
	ok = await _go(Vector3(0, -3.9, -133.5), "exit", 60.0, 0.0)
	await get_tree().create_timer(1.0).timeout
	_check(ok and bool(level.get("_ended")), "walked through the exit gate: end-of-slice screen")
	Engine.time_scale = 1.0
	print("full_run_test: game time %.0f s (bot at 2x speed), deaths %d, damage absorbed by god mode %.0f, level %d, Ka %d" % [_game_time, GameState.deaths, _damage_taken, GameState.total_level(), GameState.ka])
	print("full_run_test: %d failures" % _failures)
	SaveSystem.delete_save()
	get_tree().quit(1 if _failures > 0 else 0)
