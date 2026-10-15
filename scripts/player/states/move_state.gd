extends PlayerState
## Free locomotion. Every action starts from here (or from a cancel window).


func enter(_msg: Dictionary) -> void:
	player.animator.play_locomotion()
	player.hitbox.deactivate()
	player.trail.emitting = false


func physics_update(dt: float) -> void:
	player.handle_lock_input()
	if player.try_actions({"dodge": true, "attack": true, "ranged": true, "heal": true, "interact": true}):
		return
	player.locomote(player.input.move_world(), player.stats.run_speed, dt)


func accepts(_kind: StringName) -> bool:
	return true
