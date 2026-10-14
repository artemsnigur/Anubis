class_name TrainingDummy
extends EnemyBase
## Training dummy: never attacks, shows damage numbers, can be staggered,
## refills its health instead of dying.


func should_detect_player() -> bool:
	return false


func become_aware() -> void:
	return


func recover_state() -> StringName:
	return &"Idle"


func _on_hit_received(hit: HitInfo) -> void:
	var before := health.current
	super._on_hit_received(hit)
	Vfx.damage_number(global_position + Vector3.UP * 2.0, before - health.current + (hit.damage if is_dead else 0.0),
		Color(1.0, 0.55, 0.3) if fsm.is_in(&"Stagger") else Color(1.0, 0.9, 0.6))


func _on_death(_hit: HitInfo) -> void:
	# Refill instead of dying.
	is_dead = false
	health.revive_full()
	flash_fx.flash(Color(0.4, 1.0, 0.8), 0.4, 0.8)
