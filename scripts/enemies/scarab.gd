class_name Scarab
extends EnemyBase
## Scarab: small, fast swarm beetle with a lunging bite. Low HP, no poise.


func _combatant_ready() -> void:
	super._combatant_ready()
	telegraph_color = Color(1.0, 0.8, 0.35)


func _footstep(_side: StringName) -> void:
	return
