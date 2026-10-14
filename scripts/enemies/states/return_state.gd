extends EnemyState
## Lost the player: walk back home and reset.


func enter(_msg: Dictionary) -> void:
	enemy.animator.play_locomotion()
	enemy.release_token()


func physics_update(dt: float) -> void:
	if think(dt) and enemy.should_detect_player() and enemy.flat_distance_to(enemy.home_position) < enemy.data.leash_radius * 0.8:
		transition(&"Chase")
		return
	var d := enemy.nav_move_to(enemy.home_position, enemy.data.walk_speed * 1.3, dt)
	enemy.animator.set_locomotion_blend(enemy.move_velocity.length() / maxf(enemy.data.run_speed, 0.1))
	if d < 0.8 or time_in_state > 12.0:
		enemy.health.heal(enemy.health.max_health)
		enemy.poise.restore()
		transition(&"Idle")
