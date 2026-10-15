extends PlayerState
## Dodge roll. Starts moving in the tick the button is read, direction from the move
## input (not the facing), front-loaded distance curve 1-(1-u)^p, i-frames in
## [iframe_start, iframe_end), passes through enemies. Windows: attack after
## dodge_attack_cancel, another dodge after dodge_dodge_cancel, walking after
## dodge_move_cancel. The clip is time-scaled to the preset's duration.

var _dir: Vector3 = Vector3.FORWARD
var _speed: float = 0.0


func enter(_msg: Dictionary) -> void:
	var f := player.feel
	player.spend_stamina(player.stats.dodge_stamina)
	var m := player.input.move_world()
	_dir = m.normalized() if m.length() > 0.2 else player.forward()
	player.face_instant(_dir)
	player.animator.play(&"dodge", true)
	player.animator.set_action_speed(player.animator.clip_length(&"dodge") / maxf(f.dodge_duration, 0.05))
	player.motion.dodge_squash()
	player.set_enemy_collision(false)
	player.hitbox.deactivate()
	player.trail.emitting = false
	AudioManager.play_event(&"dodge", player.global_position)
	Vfx.dust(player.global_position - _dir * 0.3, 8, 1.1)


func exit() -> void:
	player.set_enemy_collision(true)
	player.animator.set_action_speed(1.0)


func has_iframes() -> bool:
	var f := player.feel
	return reached(f.iframe_start) and not reached(f.iframe_end)


func accepts(kind: StringName) -> bool:
	var f := player.feel
	match kind:
		&"attack":
			return reached(f.dodge_attack_cancel)
		&"dodge":
			return reached(f.dodge_dodge_cancel)
		&"move":
			return reached(f.dodge_move_cancel)
	return false


func windows() -> Dictionary:
	var f := player.feel
	return {"name": "dodge", "t": time_in_state, "total": f.dodge_duration,
		"phases": [[f.iframe_start, Color(0.45, 0.55, 0.7)], [f.iframe_end - f.iframe_start, Color(0.35, 0.6, 1.0)],
			[maxf(f.dodge_duration - f.iframe_end, 0.0), Color(0.45, 0.55, 0.7)]],
		"marks": {"attack": f.dodge_attack_cancel, "dodge": f.dodge_dodge_cancel, "move": f.dodge_move_cancel}}


func physics_update(dt: float) -> void:
	var f := player.feel
	var d := maxf(f.dodge_duration, 0.05)
	# Distance curve D(u) = 1-(1-u)^p; velocity = the distance of this tick / dt, so the
	# first tick already moves and the total is exactly dodge_distance.
	if dt > 0.0:
		var p := f.dodge_curve_power
		var u0 := clampf((time_in_state - dt) / d, 0.0, 1.0)
		var u1 := clampf(time_in_state / d, 0.0, 1.0)
		_speed = f.dodge_distance * (pow(1.0 - u0, p) - pow(1.0 - u1, p)) / dt
	player.move_velocity = _dir * _speed * player.speed_multiplier
	if accepts(&"attack") and player.try_actions({"attack": true, "ranged": true}):
		return
	if accepts(&"dodge") and player.try_actions({"dodge": true}):
		return
	if reached(d):
		player.move_velocity = _dir * player.stats.run_speed * f.dodge_exit_carry
		player.motion.land_squash(0.5)
		transition(&"Move")
		return
	if accepts(&"move") and player.input.move_world().length() > 0.3:
		player.move_velocity = _dir * minf(_speed, player.stats.run_speed)
		player.motion.land_squash(0.4)
		transition(&"Move")
