extends PlayerState
## Death: collapse, then signal the level after a beat.

var _signalled: bool = false


func enter(_msg: Dictionary) -> void:
	_signalled = false
	player.animator.play(&"death", true)
	player.hitbox.deactivate()
	player.trail.emitting = false
	player.hurtbox.monitorable = false
	player.lock_on.release()
	player.move_velocity = Vector3.ZERO
	AudioManager.play_event(&"player_death")
	CameraShake.add_trauma(0.6)
	HitStop.slow_motion(0.35, 0.6)


func can_be_interrupted() -> bool:
	return false


func physics_update(dt: float) -> void:
	player.move_velocity = player.move_velocity.move_toward(Vector3.ZERO, 30.0 * dt)
	if not _signalled and time_in_state >= 1.8:
		_signalled = true
		player.notify_death_finished()


func on_anim_event(event: StringName, _tag: StringName) -> void:
	if event == &"body_fall":
		Vfx.shards(player.global_position + Vector3.UP * 0.4, Vector3.UP, 24)
		Vfx.dust(player.global_position, 12, 1.5)
		AudioManager.play_event(&"player_hurt", player.global_position, 3.0)
