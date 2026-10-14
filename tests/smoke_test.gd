extends Node
## Smoke test: instantiates the player, every enemy type and the boss in the test
## arena, runs ~10 s of simulation with a bot spamming attacks / dodges / casts,
## and logs what happened. Exit code 0 = no crash and core systems exercised.
## godot --headless res://tests/smoke_test.tscn

const ENEMY_SCENES: Array[String] = [
	"res://scenes/enemies/training_dummy.tscn",
	"res://scenes/enemies/mummy.tscn",
	"res://scenes/enemies/scarab.tscn",
	"res://scenes/enemies/jackal.tscn",
	"res://scenes/enemies/cobra.tscn",
	"res://scenes/enemies/ammit.tscn",
]
const DURATION := 10.0

var arena: Node3D
var player: Player
var enemies: Array[Node] = []
var _t: float = 0.0
var _next_action: float = 0.0
var _rng := RandomNumberGenerator.new()
var _player_states: Dictionary = {}
var _enemy_states: Dictionary = {}
var _hits_landed: int = 0
var _hits_taken: int = 0
var _damage_dealt: float = 0.0
var _actions: Dictionary = {}
var _done: bool = false


func _ready() -> void:
	_rng.seed = 1234
	arena = (load("res://scenes/levels/test_arena.tscn") as PackedScene).instantiate()
	arena.set("spawn_dummies", false)
	add_child(arena)
	player = arena.get("player")
	player.god_mode = true
	player.input.bot_enabled = true
	player.fsm.state_changed.connect(func(_f: StringName, to: StringName) -> void: _player_states[to] = int(_player_states.get(to, 0)) + 1)
	player.hitbox.hit_landed.connect(func(_t2: Node3D, h: HitInfo) -> void:
		_hits_landed += 1
		_damage_dealt += h.damage)
	player.damaged.connect(func(_h: HitInfo) -> void: _hits_taken += 1)
	var i := 0
	for path in ENEMY_SCENES:
		if not ResourceLoader.exists(path):
			print("smoke_test: (missing scene, skipped) ", path)
			continue
		var e := (load(path) as PackedScene).instantiate() as Node3D
		arena.add_child(e)
		var ang := TAU * float(i) / float(ENEMY_SCENES.size())
		var r := 9.0 if not path.contains("ammit") else 12.0
		e.global_position = Vector3(cos(ang) * r, 0.2, sin(ang) * r - 2.0)
		if e.has_signal(&"state_logged") or e.get("fsm") != null:
			var fsm := e.get("fsm") as StateMachine
			if fsm != null:
				var key := e.name
				fsm.state_changed.connect(func(_f: StringName, to: StringName) -> void:
					var d: Dictionary = _enemy_states.get(key, {})
					d[to] = true
					_enemy_states[key] = d)
		enemies.append(e)
		i += 1
	print("smoke_test: spawned player + %d enemies" % enemies.size())


func _physics_process(delta: float) -> void:
	if _done:
		return
	_t += delta
	# Bot: wander toward the nearest enemy, spam actions.
	var target := _nearest_enemy()
	var to := Vector3.ZERO
	if target != null:
		to = target.global_position - player.global_position
		to.y = 0.0
	var mv := Vector2(to.x, to.z).normalized() if to.length() > 2.2 else Vector2(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1)) * 0.5
	player.input.bot_move = mv
	player.input.bot_aim = to.normalized() if to.length() > 0.1 else Vector3.ZERO
	if _t >= _next_action:
		_next_action = _t + _rng.randf_range(0.08, 0.3)
		var roll := _rng.randf()
		var action: StringName
		if roll < 0.45:
			action = &"attack_light"
		elif roll < 0.6:
			action = &"dodge"
		elif roll < 0.72:
			action = &"attack_heavy"
		elif roll < 0.82:
			action = &"ranged"
			player.energy = 4.0
		elif roll < 0.88:
			action = &"heal"
		else:
			action = &"lock_on"
		player.input.bot_press(action)
		player.input.bot_hold(&"attack_heavy", action == &"attack_heavy")
		_actions[action] = int(_actions.get(action, 0)) + 1
	if _t >= DURATION:
		_finish()


func _nearest_enemy() -> Node3D:
	var best: Node3D = null
	var bd := INF
	for e in enemies:
		if not is_instance_valid(e) or bool(e.get("is_dead")):
			continue
		var d := (e as Node3D).global_position.distance_to(player.global_position)
		if d < bd:
			bd = d
			best = e
	return best


func _finish() -> void:
	_done = true
	print("smoke_test: simulated %.1f s" % _t)
	print("  bot actions: ", _actions)
	print("  player states entered: ", _player_states)
	print("  player hits landed: %d (%.0f damage), hits taken: %d" % [_hits_landed, _damage_dealt, _hits_taken])
	for k: Variant in _enemy_states:
		print("  %s states: %s" % [k, (_enemy_states[k] as Dictionary).keys()])
	for e in enemies:
		if is_instance_valid(e):
			print("  %s alive=%s hp=%s" % [e.name, not bool(e.get("is_dead")), str(e.get("health").get("current")) if e.get("health") != null else "?"])
	var ok := _player_states.has(&"Attack") and _player_states.has(&"Dodge")
	print("smoke_test: ", "OK" if ok else "FAILED")
	get_tree().quit(0 if ok else 1)
