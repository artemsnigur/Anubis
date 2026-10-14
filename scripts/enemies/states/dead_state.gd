extends EnemyState
## Death: collapse, crumble into sand, then disappear.

var _sunk: bool = false


func enter(_msg: Dictionary) -> void:
	enemy.animator.play(&"death", true)
	enemy.hitbox.deactivate()
	enemy.hurtbox.monitorable = false
	enemy.collision_layer = 0
	enemy.collision_mask = CombatTypes.LAYER_WORLD
	enemy.move_velocity = Vector3.ZERO
	_sunk = false


func can_be_interrupted() -> bool:
	return false


func physics_update(dt: float) -> void:
	enemy.stop(dt, 10.0)
	if time_in_state > 1.3 and not _sunk:
		_sunk = true
		enemy.motion.enabled = false
		var dur := 2.2 if enemy.is_in_group(&"boss") else 1.3
		enemy.crumble(dur)
		Vfx.sand_burst(enemy.global_position + Vector3.UP * 0.8, Vector3.UP, 26)
		Vfx.dust(enemy.global_position, 12, 1.6)
		var tw := enemy.create_tween()
		tw.tween_interval(dur * 0.5)
		tw.tween_callback(func() -> void: Vfx.sand_burst(enemy.global_position + Vector3.UP * 0.3, Vector3.UP, 18))
		tw.tween_property(enemy.visual, "position:y", -0.25, dur * 0.5)
		tw.tween_callback(enemy.queue_free)
