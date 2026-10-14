class_name EnemySpawner
extends Marker3D
## Spawns (and on rest/death respawns) an enemy or a group of enemies.

@export var enemy_scene: PackedScene
@export var count: int = 1
@export var spread: float = 1.6
## World-space patrol points for the spawned enemy (single enemies only).
@export var patrol_points: Array[Vector3] = []
## Ambush: not spawned with the level; trigger() bursts the enemies out of the sand.
@export var deferred: bool = false

var spawned: Array[EnemyBase] = []
var triggered: bool = false


func _ready() -> void:
	add_to_group(&"spawners")


func spawn(container: Node) -> void:
	if enemy_scene == null:
		return
	for i in count:
		var e := enemy_scene.instantiate() as EnemyBase
		var offset := Vector3.ZERO
		if count > 1:
			var a := TAU * float(i) / float(count) + 0.4
			offset = Vector3(cos(a), 0.0, sin(a)) * spread * (0.6 + 0.4 * float(i % 2))
		e.position = global_position + offset + Vector3.UP * 0.1
		e.rotation.y = global_rotation.y
		if count == 1:
			e.patrol_points = patrol_points
		container.add_child(e)
		e.set_home(e.global_position, global_rotation.y)
		e.reset_physics_interpolation()
		spawned.append(e)


func despawn() -> void:
	for e in spawned:
		if is_instance_valid(e):
			e.release_token()
			e.queue_free()
	spawned.clear()


func respawn(container: Node) -> void:
	despawn()
	triggered = false
	if not deferred:
		spawn(container)


## Ambush: spawn now, already hunting the player.
func trigger(container: Node) -> void:
	if triggered:
		return
	triggered = true
	spawn(container)
	for e in spawned:
		Vfx.sand_burst(e.global_position + Vector3.UP * 0.5, Vector3.UP, 22)
		Vfx.dust(e.global_position, 10, 1.4)
		e.become_aware()
	AudioManager.play_event(&"burrow", global_position, -4.0)


func alive_count() -> int:
	var n := 0
	for e in spawned:
		if is_instance_valid(e) and not e.is_dead:
			n += 1
	return n
