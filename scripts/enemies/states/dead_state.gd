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
	if time_in_state > 1.6 and not _sunk:
		_sunk = true
		enemy.motion.enabled = false
		Vfx.sand_burst(enemy.global_position + Vector3.UP * 0.5, Vector3.UP, 20)
		Vfx.dust(enemy.global_position, 10, 1.4)
		var tw := enemy.create_tween()
		tw.tween_property(enemy.visual, "position:y", -1.6, 1.2).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(enemy.visual, "scale", Vector3(1.2, 0.3, 1.2), 1.2)
		tw.tween_callback(enemy.queue_free)
