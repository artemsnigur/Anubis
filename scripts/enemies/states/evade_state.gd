extends EnemyState
## Quick sidestep / backstep with i-frames (Jackal Warrior reading the player's swing).

var _dir: Vector3 = Vector3.ZERO


func enter(_msg: Dictionary) -> void:
	enemy.animator.play(&"evade", true)
	enemy.evade_cooldown = enemy.data.evade_cooldown
	var to := enemy.direction_to_node(enemy.player) if enemy.player_alive() else enemy.forward()
	var side := to.cross(Vector3.UP) * (1.0 if randf() < 0.5 else -1.0)
	_dir = (side * 0.75 - to * 0.65).normalized()
	enemy.hurtbox.invulnerable = true
	enemy.motion.stretch_impulse(0.2)
	Vfx.dust(enemy.global_position, 6)
	AudioManager.play_event(&"dodge", enemy.global_position)


func exit() -> void:
	enemy.hurtbox.invulnerable = false


func physics_update(dt: float) -> void:
	var u := clampf(time_in_state / 0.32, 0.0, 1.0)
	enemy.move_velocity = _dir * 11.0 * pow(1.0 - u, 1.5)
	enemy.face_player(dt, 720.0)
	if time_in_state > 0.22:
		enemy.hurtbox.invulnerable = false
	if time_in_state >= 0.38:
		# Counter-attack right after a successful read.
		var a := enemy.choose_attack()
		if a != null and enemy.request_token():
			transition(&"Attack", {"attack": a})
		else:
			transition(&"Strafe")
