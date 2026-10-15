extends PlayerState
## Hit stun. Short for light hits, longer (knocked back) for heavy hits.
## Presses made during the stun stay buffered and fire when the dodge window opens.

var _duration: float = 0.3


func enter(msg: Dictionary) -> void:
	var heavy := bool(msg.get("heavy", false))
	_duration = player.stats.heavy_hurt_duration if heavy else player.stats.hurt_duration
	player.animator.play(&"hit_heavy" if heavy else &"hit", true)
	player.hitbox.deactivate()
	player.trail.emitting = false


func accepts(kind: StringName) -> bool:
	# Late part of the stun can be dodge-cancelled so stacked enemies feel fair.
	return kind == &"dodge" and reached(_duration * 0.75)


func windows() -> Dictionary:
	return {"name": "hurt", "t": time_in_state, "total": _duration,
		"phases": [[_duration, Color(0.8, 0.3, 0.3)]], "marks": {"dodge": _duration * 0.75}}


func physics_update(dt: float) -> void:
	player.move_velocity = player.move_velocity.move_toward(Vector3.ZERO, 50.0 * dt)
	if accepts(&"dodge") and player.try_actions({"dodge": true}):
		return
	if time_in_state >= _duration:
		transition(&"Move")
