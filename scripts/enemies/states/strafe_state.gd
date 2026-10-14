extends EnemyState
## Circles the player at strafe radius while waiting for an attack token, then
## approaches into range of the chosen attack and starts it.

var _planned: EnemyAttackData
var _switch_t: float = 0.0
var _has_token: bool = false


func enter(_msg: Dictionary) -> void:
	enemy.animator.play_locomotion()
	_planned = null
	_switch_t = randf_range(1.5, 3.5)
	_has_token = false


func exit() -> void:
	if _has_token and not machine.is_in(&"Attack"):
		enemy.release_token()


func physics_update(dt: float) -> void:
	if not enemy.player_alive() or enemy.should_give_up():
		if _has_token:
			enemy.release_token()
			_has_token = false
		transition(&"Return")
		return
	var d := enemy.distance_to_player()
	if d > enemy.data.strafe_radius + 4.0 and not _has_token:
		transition(&"Chase")
		return
	if enemy.has_method(&"strafe_special") and bool(enemy.call(&"strafe_special", dt)):
		return
	if think(dt):
		if _planned == null or not enemy.attack_available(_planned):
			_planned = enemy.choose_attack(true)
		if not _has_token and _planned != null:
			_has_token = enemy.request_token()
		if _has_token:
			var now := enemy.choose_attack()
			if now != null:
				_has_token = false
				transition(&"Attack", {"attack": now})
				return
	enemy.face_player(dt)
	if _has_token and _planned != null and d > _planned.range_max * 0.85:
		# Close in for the planned attack.
		enemy.nav_move_to(enemy.player.global_position, enemy.data.run_speed, dt, false)
	else:
		_circle(dt, d)
	enemy.animator.set_locomotion_blend(enemy.move_velocity.length() / maxf(enemy.data.run_speed, 0.1))


func _circle(dt: float, d: float) -> void:
	_switch_t -= dt
	if _switch_t <= 0.0:
		_switch_t = randf_range(1.5, 3.5)
		enemy.strafe_dir *= -1.0
	var to := enemy.direction_to_node(enemy.player)
	var tangent := to.cross(Vector3.UP) * enemy.strafe_dir
	var radial := 0.0
	var r := enemy.data.strafe_radius
	if d < r - 0.8:
		radial = -1.0
	elif d > r + 0.8:
		radial = 1.0
	var dir := (tangent * 0.8 + to * radial).normalized()
	# Do not strafe into walls: probe ahead.
	var space := enemy.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(enemy.global_position + Vector3.UP * 0.5, enemy.global_position + Vector3.UP * 0.5 + dir * 1.5, CombatTypes.LAYER_WORLD | CombatTypes.LAYER_GATE)
	if not space.intersect_ray(q).is_empty():
		enemy.strafe_dir *= -1.0
		dir = (to.cross(Vector3.UP) * enemy.strafe_dir * 0.8 + to * radial).normalized()
	enemy.steer(dir, enemy.data.strafe_speed, dt)
