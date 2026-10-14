extends Node
## Capture helper: walks the player into the Hall of Two Truths and fights Ammit.
## --phase=2 drops Ammit below 50 % HP to show the second phase.

var level: Level
var player: Player
var _t: float = 0.0
var _phase: int = 1
var _next: float = 0.0


func setup(scene: Node, args: Dictionary) -> void:
	level = scene as Level
	_phase = int(args.get("phase", "1"))
	player = level.player
	player.input.bot_enabled = true
	player.god_mode = true
	_go.call_deferred()


func _go() -> void:
	player.teleport_to(Vector3(2, -3.9, -99), PI)
	level.camera.snap_to_target()


func _physics_process(delta: float) -> void:
	_t += delta
	var arena := level.get("boss_arena") as BossArena
	if arena == null or arena.boss == null or not is_instance_valid(arena.boss):
		return
	var b := arena.boss
	if _phase == 2 and b.phase == 1 and _t > 1.0:
		b.health.current = b.health.max_health * 0.49
		b.health.damage(1.0)
	var to := b.global_position - player.global_position
	to.y = 0.0
	var cam := player.input.camera
	var r := cam.global_basis.x
	r.y = 0.0
	var f := -cam.global_basis.z
	f.y = 0.0
	var dir := to.normalized()
	player.input.bot_move = Vector2(dir.dot(r.normalized()), -dir.dot(f.normalized())) if to.length() > 4.5 else Vector2.ZERO
	player.input.bot_aim = dir
	if _t > _next and to.length() < 5.0:
		_next = _t + 0.35
		player.input.bot_press(&"attack_light")
