extends EnemyState
## Path to the player until within strafing range.


func enter(_msg: Dictionary) -> void:
	enemy.animator.play_locomotion()


func physics_update(dt: float) -> void:
	if not enemy.player_alive() or enemy.should_give_up():
		transition(&"Return")
		return
	var d := enemy.distance_to_player()
	enemy.nav_move_to(enemy.player.global_position, enemy.data.run_speed, dt)
	enemy.animator.set_locomotion_blend(enemy.move_velocity.length() / maxf(enemy.data.run_speed, 0.1))
	if d <= enemy.data.strafe_radius + 1.0:
		transition(&"Strafe")
		return
	# Long-range attacks (spit, leap, charge) can start straight from a chase.
	if think(dt) and d > enemy.data.strafe_radius + 1.0:
		var a := enemy.choose_attack()
		if a != null and a.range_min > 0.0 and enemy.can_see_player() and enemy.request_token():
			transition(&"Attack", {"attack": a})
