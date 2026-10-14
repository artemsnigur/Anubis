extends EnemyState
## Boss waiting for the fight to start (BossArena calls enemy.awaken()).


func enter(_msg: Dictionary) -> void:
	enemy.animator.play_locomotion()
	enemy.move_velocity = Vector3.ZERO


func physics_update(dt: float) -> void:
	enemy.stop(dt)
	enemy.animator.set_locomotion_blend(0.0)


func can_be_interrupted() -> bool:
	return false
