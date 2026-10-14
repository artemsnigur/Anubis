extends EnemyState
## Micro-stagger on a hit (interrupts non-armoured actions).


func enter(_msg: Dictionary) -> void:
	enemy.animator.play(&"hit", true)
	enemy.hitbox.deactivate()
	enemy.release_token()


func physics_update(dt: float) -> void:
	enemy.stop(dt, 25.0)
	if time_in_state >= enemy.data.flinch_duration:
		transition(enemy.recover_state())
