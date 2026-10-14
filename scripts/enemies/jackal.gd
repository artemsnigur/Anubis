class_name Jackal
extends EnemyBase
## Jackal Warrior: agile 3-hit combo, gap-closing lunge, sidesteps around the player
## and sometimes reads the player's swing and evades it.

var _player_was_attacking: bool = false
var _sidestep_t: float = 3.0


func _pre_update(dt: float, real_dt: float) -> void:
	super._pre_update(dt, real_dt)
	var attacking := player_is_attacking()
	if attacking and not _player_was_attacking:
		_on_player_attack_started()
	_player_was_attacking = attacking


func _on_player_attack_started() -> void:
	if is_dead or evade_cooldown > 0.0:
		return
	if not (fsm.is_in(&"Strafe") or fsm.is_in(&"Chase")):
		return
	if distance_to_player() > 3.6:
		return
	if randf() < data.evade_chance:
		fsm.transition_to(&"Evade")


## Called by the Strafe state every frame; occasional sidestep hops.
func strafe_special(dt: float) -> bool:
	_sidestep_t -= dt
	if _sidestep_t <= 0.0 and evade_cooldown <= 0.0:
		_sidestep_t = randf_range(2.5, 4.5)
		if distance_to_player() < 5.0 and randf() < 0.5:
			fsm.transition_to(&"Evade")
			return true
	return false
