extends PlayerState
## Hit stun. Short for light hits, longer (knocked back) for heavy hits.

var _duration: float = 0.3


func enter(msg: Dictionary) -> void:
	var heavy := bool(msg.get("heavy", false))
	_duration = player.stats.heavy_hurt_duration if heavy else player.stats.hurt_duration
	player.animator.play(&"hit_heavy" if heavy else &"hit", true)
	player.hitbox.deactivate()
	player.trail.emitting = false
	player.input.clear_buffer()


func physics_update(dt: float) -> void:
	player.move_velocity = player.move_velocity.move_toward(Vector3.ZERO, 50.0 * dt)
	# Late part of the stun can be dodge-cancelled so stacked enemies feel fair.
	if time_in_state >= _duration * 0.75 and player.try_actions({"dodge": true}):
		return
	if time_in_state >= _duration:
		transition(&"Move")
