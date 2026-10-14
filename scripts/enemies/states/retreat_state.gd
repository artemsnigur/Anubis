extends EnemyState
## Backs away from a player that got too close (Cobra Priestess).


func enter(_msg: Dictionary) -> void:
	enemy.animator.play_locomotion()


func physics_update(dt: float) -> void:
	if not enemy.player_alive():
		transition(&"Return")
		return
	var away := -enemy.direction_to_node(enemy.player)
	var space := enemy.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(enemy.global_position + Vector3.UP * 0.5, enemy.global_position + Vector3.UP * 0.5 + away * 2.0, CombatTypes.LAYER_WORLD | CombatTypes.LAYER_GATE)
	if not space.intersect_ray(q).is_empty():
		away = away.rotated(Vector3.UP, deg_to_rad(80.0) * enemy.strafe_dir)
	enemy.steer(away, enemy.data.run_speed, dt)
	enemy.face_player(dt)
	enemy.animator.set_locomotion_blend(enemy.move_velocity.length() / maxf(enemy.data.run_speed, 0.1))
	var d := enemy.distance_to_player()
	if d > enemy.data.retreat_radius + 3.0 or time_in_state > 1.6:
		transition(&"Strafe")
		return
	# Cornered and the player is right there: lash out.
	if time_in_state > 0.5 and d < 2.2:
		var a := enemy.choose_attack()
		if a != null:
			transition(&"Attack", {"attack": a})
