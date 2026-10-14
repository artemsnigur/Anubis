extends Node
## Capture helper: places the player near the courtyard mummy and kills it.

var level: Level
var _t: float = 0.0
var _done: bool = false


func setup(scene: Node, _args: Dictionary) -> void:
	level = scene as Level
	_go.call_deferred()


var _target: EnemyBase


func _go() -> void:
	for e in get_tree().get_nodes_in_group(&"enemies"):
		if e is Mummy:
			_target = e as EnemyBase
			break
	var p := _target.global_position + Vector3(2.5, 0.0, 2.5)
	level.player.teleport_to(p, 0.0)
	level.camera.snap_to_target()
	level.player.input.bot_enabled = true


func _physics_process(delta: float) -> void:
	_t += delta
	if _t > 0.8 and not _done:
		_done = true
		if is_instance_valid(_target):
			var h := HitInfo.new()
			h.damage = 9999.0
			h.direction = Vector3.FORWARD
			_target.hurtbox.receive_hit(h)
