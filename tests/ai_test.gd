extends Node
## AI checks: navigation around obstacles and the attack-token limit.
## godot --headless res://tests/ai_test.tscn

var arena: Node3D
var player: Player
var _failures: int = 0
var _log: PackedStringArray = []
var _max_tokens_seen: int = 0
var _director: AIDirector


func _ready() -> void:
	arena = (load("res://scenes/levels/test_arena.tscn") as PackedScene).instantiate()
	arena.set("spawn_dummies", false)
	add_child(arena)
	player = arena.get("player")
	player.input.bot_enabled = true
	player.god_mode = true
	_run.call_deferred()


func _check(cond: bool, msg: String) -> void:
	_log.append(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, false, true).timeout


func _physics_process(_delta: float) -> void:
	if _director == null:
		_director = get_tree().get_first_node_in_group(&"ai_director") as AIDirector
	if _director != null:
		_director._clean()
		_max_tokens_seen = maxi(_max_tokens_seen, _director.holders.size())


func _spawn(path: String, pos: Vector3) -> EnemyBase:
	var e := (load(path) as PackedScene).instantiate() as EnemyBase
	arena.add_child(e)
	e.global_position = pos
	e.set_home(pos, 0.0)
	return e


func _run() -> void:
	await _wait(0.3)
	# 1. Navigation: jackal on the other side of the wall segment (x -12..-4 at z = 10).
	player.teleport_to(Vector3(-8, 0.1, 6.5), 0.0)
	var j := _spawn("res://scenes/enemies/jackal.tscn", Vector3(-8, 0.1, 13.5))
	j.data = j.data.duplicate()
	j.data.detect_radius = 0.0
	j.data.attacks = []
	j.become_aware()
	await _wait(5.0)
	var d := j.flat_distance_to(player.global_position)
	_check(d < j.data.strafe_radius + 2.0, "jackal paths around the wall to the player (distance %.1f)" % d)
	j.queue_free()
	await _wait(0.2)
	# 2. Token limit with a scarab swarm.
	player.teleport_to(Vector3(0, 0.1, 0), 0.0)
	var swarm: Array[EnemyBase] = []
	for i in 6:
		var a := TAU * float(i) / 6.0
		swarm.append(_spawn("res://scenes/enemies/scarab.tscn", Vector3(cos(a) * 5.0, 0.1, sin(a) * 5.0)))
	for s in swarm:
		s.become_aware()
	_max_tokens_seen = 0
	var attack_frames := 0
	for i in 360:
		await get_tree().physics_frame
		var attacking := 0
		for s in swarm:
			if is_instance_valid(s) and s.fsm.is_in(&"Attack"):
				attacking += 1
		attack_frames = maxi(attack_frames, attacking)
	_check(_max_tokens_seen <= 2, "no more than 2 attack tokens held at once (max %d)" % _max_tokens_seen)
	_check(attack_frames <= 2 and attack_frames >= 1, "swarm attacks, at most 2 at a time (max simultaneous %d)" % attack_frames)
	var strafing := 0
	for s in swarm:
		if is_instance_valid(s) and (s.fsm.is_in(&"Strafe") or s.fsm.is_in(&"Chase")):
			strafing += 1
	_check(strafing >= 2, "the rest of the swarm circles (%d strafing/chasing)" % strafing)
	for l in _log:
		print(l)
	print("ai_test: %d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
