extends Node
## Headless verification of the combat core against a training dummy.
## godot --headless res://tests/combat_test.tscn

var arena: Node3D
var player: Player
var dummy: EnemyBase
var _failures: int = 0
var _log: PackedStringArray = []
var _hitstop_seen_player: bool = false
var _hitstop_seen_dummy: bool = false


func _ready() -> void:
	GameState.set_feel_preset(GameState.DEFAULT_FEEL, false)
	# Watchdog: never hang a CI run.
	get_tree().create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("combat_test: TIMEOUT")
		get_tree().quit(2))
	arena = (load("res://scenes/levels/test_arena.tscn") as PackedScene).instantiate()
	arena.set("spawn_dummies", false)
	add_child(arena)
	player = arena.get("player")
	player.input.bot_enabled = true
	dummy = (load("res://scenes/enemies/training_dummy.tscn") as PackedScene).instantiate() as EnemyBase
	arena.add_child(dummy)
	dummy.global_position = Vector3(0, 0, 0)
	player.teleport_to(Vector3(0, 0.1, 1.8), 0.0)
	_run.call_deferred()


func _physics_process(_delta: float) -> void:
	if player.hitstop_left > 0.0:
		_hitstop_seen_player = true
	if dummy != null and dummy.hitstop_left > 0.0:
		_hitstop_seen_dummy = true


func _check(cond: bool, msg: String) -> void:
	_log.append(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false, true).timeout


func _reset_dummy() -> void:
	dummy.health.revive_full()
	dummy.poise.restore()
	dummy.fsm.transition_to(&"Idle")
	await _wait(0.4)


func _run() -> void:
	await _wait(0.5)
	player.input.bot_aim = Vector3.FORWARD
	# 1. Light hit: damage, hitstop on both, energy, shake.
	var hp0 := dummy.health.current
	var e0 := player.energy
	player.input.bot_press(&"attack_light")
	await _wait(0.45)
	_check(is_equal_approx(hp0 - dummy.health.current, 14.0), "light hit deals 14 (dealt %.1f)" % (hp0 - dummy.health.current))
	_check(_hitstop_seen_player and _hitstop_seen_dummy, "local hitstop freezes attacker and target")
	_check(is_equal_approx(player.energy - e0, 0.25), "melee hit grants 0.25 solar energy (%.2f)" % (player.energy - e0))
	_check(player.game_camera != null and player.game_camera.trauma >= 0.0, "camera registered for shake")
	await _wait(0.6)

	# 2. Fully charged heavy.
	await _reset_dummy()
	hp0 = dummy.health.current
	player.input.bot_hold(&"attack_heavy", true)
	player.input.bot_press(&"attack_heavy")
	await _wait(0.4 + 0.85)
	player.input.bot_hold(&"attack_heavy", false)
	await _wait(0.5)
	var heavy := hp0 - dummy.health.current
	_check(heavy > 55.0, "charged heavy deals ~57.6 (dealt %.1f)" % heavy)
	await _wait(0.6)

	# 3. Poise break -> stagger -> bonus damage.
	await _reset_dummy()
	var staggered := false
	for i in 6:
		player.input.bot_press(&"attack_light")
		await _wait(0.4)
		if dummy.fsm.is_in(&"Stagger"):
			staggered = true
			break
	_check(staggered, "poise break staggers the dummy")
	if staggered:
		hp0 = dummy.health.current
		player.input.bot_press(&"attack_light")
		await _wait(0.4)
		var dealt := hp0 - dummy.health.current
		_check(dealt > 14.5, "stagger window multiplies damage (dealt %.1f)" % dealt)
	await _wait(2.5)

	# 4. Dodge i-frames.
	player.health.revive_full()
	player.input.bot_press(&"dodge")
	await _wait(0.12)
	var h := HitInfo.new()
	h.damage = 20.0
	h.direction = Vector3.FORWARD
	var accepted := player.hurtbox.receive_hit(h)
	_check(not accepted and h.was_blocked_by_iframes, "hit during dodge i-frames is ignored")
	await _wait(0.6)
	var h2 := HitInfo.new()
	h2.damage = 20.0
	h2.direction = Vector3.FORWARD
	var hp_before := player.health.current
	player.hurtbox.receive_hit(h2)
	_check(player.health.current < hp_before, "hit outside i-frames deals damage")
	await _wait(0.8)

	# 5. Heal.
	player.health.current = 40.0
	var ankh0 := player.ankh
	player.input.bot_press(&"heal")
	await _wait(0.9)
	_check(player.ankh == ankh0 - 1, "heal consumes one Ankh charge")
	_check(player.health.current > 40.0 + player.health.max_health * 0.4, "heal restores 45%% (hp %.1f)" % player.health.current)

	# 6. Heal punished.
	await _wait(0.3)
	player.health.current = 40.0
	ankh0 = player.ankh
	player.input.bot_press(&"heal")
	await _wait(0.2)
	player.invulnerable_time = 0.0
	var h3 := HitInfo.new()
	h3.damage = 5.0
	h3.direction = Vector3.FORWARD
	player.hurtbox.receive_hit(h3)
	await _wait(0.8)
	_check(player.ankh == ankh0 - 1 and player.health.current < 40.0, "heal interrupted by a hit is wasted (hp %.1f)" % player.health.current)

	# 7. Eye of Ra.
	await _wait(0.5)
	await _reset_dummy()
	player.teleport_to(Vector3(0, 0.1, 6.0), 0.0)
	player.energy = 1.0
	hp0 = dummy.health.current
	player.input.bot_press(&"ranged")
	await _wait(1.0)
	_check(player.energy < 1.0, "Eye of Ra spends a charge")
	_check(hp0 - dummy.health.current > 30.0, "Eye of Ra projectile damages the target (dealt %.1f)" % (hp0 - dummy.health.current))
	player.input.bot_press(&"ranged")
	await _wait(0.3)
	_check(not player.fsm.is_in(&"Cast"), "no cast without energy")

	# 8. Input buffer: attack pressed during the dodge executes at the cancel point.
	player.teleport_to(Vector3(0, 0.1, 3.0), 0.0)
	await _wait(0.3)
	player.input.bot_press(&"dodge")
	await _wait(0.16)
	player.input.bot_press(&"attack_light")
	await _wait(0.14)
	_check(player.fsm.is_in(&"Attack"), "buffered attack fires out of the dodge (state %s)" % player.fsm.current_name())
	await _wait(0.6)

	# 9. Lock-on.
	player.teleport_to(Vector3(0, 0.1, 4.0), 0.0)
	await _wait(0.2)
	player.input.bot_press(&"lock_on")
	await _wait(0.1)
	_check(player.lock_on.target == dummy, "lock-on acquires the dummy")
	player.input.bot_press(&"lock_on")
	await _wait(0.1)
	_check(player.lock_on.target == null, "lock-on toggles off")

	for l in _log:
		print(l)
	print("combat_test: %d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
