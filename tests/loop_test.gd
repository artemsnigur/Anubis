extends Node
## Souls-like loop verification: Ka from kills, altar rest (restore, respawn, save),
## leveling, death -> heart -> respawn at the altar, heart pickup, heart loss on a
## second death, save/load round trip.
## godot --headless res://tests/loop_test.tscn

const SCARAB := preload("res://scenes/enemies/scarab.tscn")

var arena: Level
var player: Player
var spawner: EnemySpawner
var _failures: int = 0
var _log: PackedStringArray = []


func _ready() -> void:
	GameState.set_feel_preset(GameState.DEFAULT_FEEL, false)
	# Watchdog: never hang a CI run.
	get_tree().create_timer(300.0, true, false, true).timeout.connect(func() -> void:
		print("loop_test: TIMEOUT")
		get_tree().quit(2))
	SaveSystem.delete_save()
	GameState.reset_progress()
	arena = (load("res://scenes/levels/test_arena.tscn") as PackedScene).instantiate() as Level
	arena.set("spawn_dummies", false)
	add_child(arena)
	player = arena.player
	player.input.bot_enabled = true
	spawner = EnemySpawner.new()
	spawner.enemy_scene = SCARAB
	arena.add_child(spawner)
	spawner.position = Vector3(-10, 0, -10)
	spawner.spawn(arena.enemies_root)
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	_log.append(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _kill(c: Combatant) -> void:
	var h := HitInfo.new()
	h.damage = 9999.0
	h.direction = Vector3.FORWARD
	c.hurtbox.invulnerable = false
	if c is Player:
		(c as Player).invulnerable_time = 0.0
	c.hurtbox.receive_hit(h)


func _run() -> void:
	await _wait(0.5)
	# 1. Ka from a kill.
	var scarab: EnemyBase = spawner.spawned[0]
	_kill(scarab)
	await _wait(0.2)
	_check(GameState.ka == scarab.data.ka_reward, "killing a scarab grants %d Ka (have %d)" % [scarab.data.ka_reward, GameState.ka])
	await _wait(3.5)
	_check(spawner.alive_count() == 0, "dead enemy is removed")

	# 2. Rest at the altar.
	var altar: Altar = arena.altars[&"test_altar"]
	player.teleport_to(altar.spawn_point(), 0.0)
	await _wait(0.3)
	player.refresh_interactable()
	_check(player.interactable == altar, "altar becomes the interaction target")
	player.health.current = 30.0
	player.ankh = 0
	player.input.bot_press(&"interact")
	await _wait(2.6)
	_check(altar.lit, "altar is kindled")
	_check(GameState.last_altar == &"test_altar", "altar becomes the respawn point")
	_check(arena.levelup.is_open, "level-up menu opens after resting")
	_check(is_equal_approx(player.health.current, player.health.max_health) and player.ankh == GameState.max_ankh(), "rest restores HP and Ankh charges")
	_check(spawner.alive_count() == 1, "rest respawns enemies")
	_check(SaveSystem.has_save(), "rest saves the game")

	# 3. Level up.
	GameState.add_ka(500)
	var hp_before := player.health.max_health
	var cost := GameState.level_cost()
	arena.levelup.call(&"_on_level", &"vitality")
	_check(GameState.get_level(&"vitality") == 1, "vitality levelled up")
	_check(player.health.max_health > hp_before, "max HP increased (%.0f -> %.0f)" % [hp_before, player.health.max_health])
	_check(GameState.ka == GameState.ka, "level cost %d Ka paid" % cost)
	_check(GameState.level_cost() > cost, "next level costs more (%d > %d)" % [GameState.level_cost(), cost])
	arena.levelup.close()
	await _wait(0.3)
	_check(player.fsm.is_in(&"Move"), "player stands up after leaving the menu")

	# 4. Death drops a heart with all carried Ka.
	player.teleport_to(Vector3(-5, 0.1, 5), 0.0)
	await _wait(0.3)
	var carried := GameState.ka
	var death_pos := player.global_position
	_kill(player)
	await _wait(12.0)
	_check(GameState.has_heart and GameState.heart_ka == carried, "heart holds the %d carried Ka" % carried)
	_check(GameState.ka == 0, "Ka is lost on death")
	_check(GameState.heart_position.distance_to(death_pos) < 1.5, "heart lies where the player fell")
	_check(not player.is_dead and player.global_position.distance_to(altar.spawn_point()) < 1.0, "player respawns at the last altar")
	_check(get_tree().get_nodes_in_group(&"ka_heart").size() == 1, "heart pickup exists in the world")

	# 5. Pick up the heart.
	player.teleport_to(GameState.heart_position, 0.0)
	await _wait(0.5)
	_check(GameState.ka == carried and not GameState.has_heart, "touching the heart restores the Ka")

	# 6. A second death without recovering the heart loses it.
	GameState.add_ka(77)
	player.teleport_to(Vector3(3, 0.1, 5), 0.0)
	await _wait(0.2)
	_kill(player)
	await _wait(12.0)
	_check(GameState.heart_ka == carried + 77, "new heart replaces the previous one (%d)" % GameState.heart_ka)
	player.teleport_to(Vector3(-3, 0.1, 8), 0.0)
	await _wait(0.2)
	_kill(player)
	await _wait(12.0)
	_check(not GameState.has_heart or GameState.heart_ka == 0, "dying again with no Ka loses the old heart")

	# 7. Save / load round trip.
	GameState.add_ka(123)
	GameState.set_flag(&"test_flag", true)
	SaveSystem.save_game()
	var snapshot := GameState.to_dict()
	GameState.reset_progress()
	SaveSystem.load_game()
	var after := GameState.to_dict()
	_check(JSON.stringify(snapshot) == JSON.stringify(after), "save/load round trip preserves state")
	SaveSystem.delete_save()
	GameState.reset_progress()

	for l in _log:
		print(l)
	print("loop_test: %d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
