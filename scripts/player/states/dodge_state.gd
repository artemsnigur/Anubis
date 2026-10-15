extends PlayerState
## Dodge roll. Reacts in the tick the button is read (the body drops and pushes off),
## direction from the move input (not the facing) and committed for the whole roll.
## Speed profile: a push-off ramp (dodge_ramp_time) into a decaying burst (1-u)^(p-1),
## normalised so the roll covers dodge_distance. I-frames in [iframe_start, iframe_end),
## passes through enemies. Windows: attack after dodge_attack_cancel, another dodge after
## dodge_dodge_cancel, walking after dodge_move_cancel. The clip is retimed to the preset.

var _dir: Vector3 = Vector3.FORWARD
var _speed: float = 0.0
var _norm: float = 1.0


func enter(_msg: Dictionary) -> void:
	var f := player.feel
	player.spend_stamina(player.stats.dodge_stamina)
	player.alive.add_exertion(0.12)
	var m := player.input.move_world()
	_dir = m.normalized() if m.length() > 0.2 else player.forward()
	player.face_instant(_dir)
	# Normalisation of the speed profile (midpoint rule, matches the per-tick sampling).
	_norm = 0.0
	var d := maxf(f.dodge_duration, 0.05)
	for i in 120:
		_norm += _profile((float(i) + 0.5) / 120.0 * d) * d / 120.0
	_norm = maxf(_norm, 0.0001)
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
		_speed = f.dodge_distance * _profile(time_in_state - dt * 0.5) / _norm
	player.move_velocity = _dir * _speed * player.speed_multiplier
	if accepts(&"attack") and player.try_actions({"attack": true, "ranged": true}):
		return
	if accepts(&"dodge") and player.try_actions({"dodge": true}):
		return
	if reached(d):
		player.move_velocity = _dir * player.run_speed() * f.dodge_exit_carry
		player.motion.land_squash(0.5)
		transition(&"Move")
		return
	if accepts(&"move") and player.input.move_world().length() > 0.3:
		player.move_velocity = _dir * minf(_speed, player.run_speed())
		player.motion.land_squash(0.4)
		transition(&"Move")


## Unnormalised speed at time t: smooth push-off ramp times the decaying burst.
func _profile(t: float) -> float:
	var f := player.feel
	var d := maxf(f.dodge_duration, 0.05)
	var u := clampf(t / d, 0.0, 1.0)
	var ramp := 1.0
	if f.dodge_ramp_time > 0.0:
		var r := clampf(t / f.dodge_ramp_time, 0.0, 1.0)
		ramp = r * r * (3.0 - 2.0 * r)
	return ramp * pow(1.0 - u, maxf(f.dodge_curve_power - 1.0, 0.0))
