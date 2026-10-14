extends EnemyState
## Guarding the spawn point or walking a patrol route until the player is noticed.

var _patrol_index: int = 0
var _wait: float = 0.0


func enter(_msg: Dictionary) -> void:
	enemy.animator.play_locomotion()
	enemy.aware = false
	_wait = randf_range(0.5, 2.0)


func physics_update(dt: float) -> void:
	if think(dt) and enemy.should_detect_player():
		enemy.aware = true
		transition(&"Alert")
		return
	var pts := enemy.patrol_points
	if pts.is_empty():
		var d := enemy.flat_distance_to(enemy.home_position)
		if d > 0.6:
			enemy.nav_move_to(enemy.home_position, enemy.data.walk_speed, dt)
		else:
			enemy.stop(dt)
			enemy.face_toward(Vector3(-sin(enemy.home_yaw), 0, -cos(enemy.home_yaw)), 120.0, dt)
	else:
		if _wait > 0.0:
			_wait -= dt
			enemy.stop(dt)
		else:
			var target := pts[_patrol_index % pts.size()]
			if enemy.nav_move_to(target, enemy.data.walk_speed, dt) < 0.7:
				_patrol_index += 1
				_wait = randf_range(1.0, 2.5)
	enemy.animator.set_locomotion_blend(enemy.move_velocity.length() / maxf(enemy.data.run_speed, 0.1))
