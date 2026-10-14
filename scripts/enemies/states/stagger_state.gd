extends EnemyState
## Poise broken: long stagger, takes extra damage (punish window).


var _duration: float = 2.0


func enter(msg: Dictionary) -> void:
	_duration = float(msg.get("duration", enemy.data.stagger_duration))
	enemy.animator.play(StringName(msg.get("anim", &"stagger")), true)
	enemy.hitbox.deactivate()
	enemy.release_token()
	enemy.flash_fx.flash(Color(1.0, 0.9, 0.6), 0.4, 0.7)


func can_be_interrupted() -> bool:
	return false


func physics_update(dt: float) -> void:
	enemy.stop(dt, 12.0)
	if time_in_state >= _duration:
		enemy.poise.restore()
		transition(enemy.recover_state())
