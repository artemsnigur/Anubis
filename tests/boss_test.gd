extends Node
## Ammit fight verification with a bot player (god mode).
## godot --headless res://tests/boss_test.tscn

var level: Level
var player: Player
var arena: BossArena
var _failures: int = 0
var _log: PackedStringArray = []
var _attacks_seen: Dictionary = {}
var _states_seen: Dictionary = {}
var _bot_on: bool = false
var _next_action: float = 0.0
var _t: float = 0.0
var _rng := RandomNumberGenerator.new()
var _hits_on_player: int = 0
var _phase2_forced: bool = false


func _ready() -> void:
	# Watchdog: never hang a CI run.
	get_tree().create_timer(240.0, true, false, true).timeout.connect(func() -> void:
		print("boss_test: TIMEOUT")
		get_tree().quit(2))
	_rng.seed = 99
	SaveSystem.delete_save()
	GameState.reset_progress()
	level = (load("res://scenes/levels/necropolis.tscn") as PackedScene).instantiate() as Level
	add_child(level)
	player = level.player
	player.input.bot_enabled = true
	player.god_mode = true
	player.damaged.connect(func(_h: HitInfo) -> void: _hits_on_player += 1)
	arena = level.get("boss_arena") as BossArena
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	_log.append(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _watch_boss() -> void:
	var b := arena.boss
	b.fsm.state_changed.connect(func(_f: StringName, to: StringName) -> void:
		_states_seen[to] = true
		if to == &"Attack":
			var st := b.fsm.current
			var a := st.get("attack") as EnemyAttackData
			if a != null:
				_attacks_seen[a.id] = true)


func _physics_process(delta: float) -> void:
	_t += delta
	if arena != null and arena.boss != null and is_instance_valid(arena.boss):
		var st := arena.boss.fsm.current
		if st != null and arena.boss.fsm.is_in(&"Attack"):
			var a := st.get("attack") as EnemyAttackData
			if a != null:
				_attacks_seen[a.id] = true
	if not _bot_on or player.is_dead or arena.boss == null or not is_instance_valid(arena.boss):
		return
	# Phase 1 is exercised at > 60 % HP; phase 2 is triggered explicitly by the test.
	if not _phase2_forced and arena.boss.health.ratio() < 0.6:
		arena.boss.health.current = arena.boss.health.max_health * 0.6
	var to := arena.boss.global_position - player.global_position
	to.y = 0.0
	var cam := player.input.camera
	var right := cam.global_basis.x
	right.y = 0.0
	var fwd := -cam.global_basis.z
	fwd.y = 0.0
	var dir := to.normalized()
	# Keep at melee range, circle a little.
	if to.length() > 4.0:
		player.input.bot_move = Vector2(dir.dot(right.normalized()), -dir.dot(fwd.normalized()))
	else:
		var side := dir.cross(Vector3.UP)
		player.input.bot_move = Vector2(side.dot(right.normalized()), -side.dot(fwd.normalized())) * 0.6
	player.input.bot_aim = dir
	if _t >= _next_action:
		_next_action = _t + _rng.randf_range(0.2, 0.5)
		var r := _rng.randf()
		if r < 0.55:
			player.input.bot_press(&"attack_light")
		elif r < 0.75:
			player.input.bot_press(&"dodge")
		elif r < 0.85:
			player.input.bot_press(&"ranged")
		else:
			player.input.bot_press(&"attack_heavy")


func _run() -> void:
	await _wait(0.5)
	_check(arena != null and arena.boss != null, "Ammit spawned dormant in the Hall of Two Truths")
	_check(arena.boss.fsm.is_in(&"Dormant"), "boss waits until the player enters")
	_watch_boss()
	player.teleport_to(Vector3(0, -3.9, -97), PI)
	await _wait(0.6)
	_check(arena.fight_active, "fight starts when the player walks in")
	var veil := level.get("veil") as SandVeil
	_check(veil.active, "sand veil closes the entrance")
	_check(is_equal_approx(level.camera.zoom, 1.35), "camera zooms out for the arena")
	_bot_on = true
	await _wait(32.0)
	var b := arena.boss
	_check(b.health.current < b.health.max_health, "player damages Ammit (%d / %d)" % [int(b.health.current), int(b.health.max_health)])
	# Push into phase 2.
	_phase2_forced = true
	b.health.current = b.health.max_health * 0.48
	b.health.damage(1.0)
	await _wait(4.0)
	_check(b.phase == 2, "phase 2 below 50 % HP")
	_check(level.atmosphere.current == &"hall_rage", "lighting changes in phase 2")
	_check(arena.phase_two, "quicksand pools open")
	for k in 10:
		await _wait(4.0)
		if not is_instance_valid(b) or b.is_dead:
			break
	print("boss_test: attacks used: ", _attacks_seen.keys())
	print("boss_test: states visited: ", _states_seen.keys())
	print("boss_test: hits taken by the player: ", _hits_on_player)
	for id: StringName in [&"ammit_snap_1", &"ammit_snap_2", &"ammit_tail", &"ammit_roar"]:
		_check(_attacks_seen.has(id), "attack used: %s" % id)
	var long_range := 0
	for id: StringName in [&"ammit_charge", &"ammit_leap", &"ammit_burrow", &"ammit_summon"]:
		if _attacks_seen.has(id):
			long_range += 1
	_check(long_range >= 2, "special attacks used (%d of charge/leap/burrow/summon)" % long_range)
	_check(_hits_on_player > 0, "Ammit lands hits on the player (%d)" % _hits_on_player)
	# Kill (unless the bot already did).
	_bot_on = false
	if is_instance_valid(b) and not b.is_dead:
		var h := HitInfo.new()
		h.damage = 99999.0
		h.direction = Vector3.FORWARD
		b.hurtbox.monitorable = true
		b.hurtbox.invulnerable = false
		b.hurtbox.receive_hit(h)
	await _wait(6.0)
	_check(GameState.get_flag(&"boss_defeated"), "victory flag set")
	_check(is_equal_approx(Engine.time_scale, 1.0), "slow motion restored")
	_check((level.get("exit_gate") as Gate).is_open, "exit gate opens")
	_check(not veil.active, "sand veil drops")
	_check(get_tree().get_nodes_in_group(&"ammit_minions").filter(func(m: Node) -> bool: return not bool(m.get("is_dead"))).is_empty(), "summoned scarabs die with Ammit")
	# Reset after a death: fresh state, fight again, die, the arena resets.
	GameState.set_flag(&"boss_defeated", false)
	level.reset_world()
	await _wait(0.5)
	_check(arena.boss != null and arena.boss.fsm.is_in(&"Dormant"), "arena reset re-spawns a dormant Ammit")
	_check(not veil.active and is_equal_approx(level.camera.zoom, 1.0), "veil and camera reset")
	for l in _log:
		print(l)
	print("boss_test: %d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
