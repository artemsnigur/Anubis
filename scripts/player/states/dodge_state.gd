extends PlayerState
## Dodge roll: front-loaded burst (distance curve 1-(1-u)^p), i-frames in
## [iframe_start, iframe_end), passes through enemies, cancellable into an attack
## (or another dodge) after dodge_cancel_time.

var _dir: Vector3 = Vector3.FORWARD


func enter(_msg: Dictionary) -> void:
	var s := player.stats
	player.spend_stamina(s.dodge_stamina)
	var m := player.input.move_world()
	_dir = m.normalized() if m.length() > 0.2 else player.forward()
	player.face_instant(_dir)
	player.animator.play(&"dodge", true)
	player.motion.stretch_impulse(0.28)
	player.set_enemy_collision(false)
	player.hitbox.deactivate()
	player.trail.emitting = false
	AudioManager.play_event(&"dodge", player.global_position)
	Vfx.dust(player.global_position, 8, 1.1)


func exit() -> void:
	player.set_enemy_collision(true)


func has_iframes() -> bool:
	var s := player.stats
	return time_in_state >= s.iframe_start and time_in_state < s.iframe_end


func physics_update(_dt: float) -> void:
	var s := player.stats
	var u := clampf(time_in_state / s.dodge_duration, 0.0, 1.0)
	var p := s.dodge_curve_power
	var speed := s.dodge_distance * p * pow(1.0 - u, p - 1.0) / s.dodge_duration
	player.move_velocity = _dir * speed * player.speed_multiplier
	if time_in_state >= s.dodge_cancel_time:
		if player.try_actions({"attack": true, "dodge": true, "ranged": true}):
			return
	if time_in_state >= s.dodge_duration:
		player.move_velocity = _dir * minf(speed, s.run_speed) * 0.6
		transition(&"Move")
