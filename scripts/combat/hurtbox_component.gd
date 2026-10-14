class_name HurtboxComponent
extends Area3D
## Receives hits. Lives on the hurtbox physics layer; hitboxes query it.

signal hit_received(hit: HitInfo)

@export var faction: CombatTypes.Faction = CombatTypes.Faction.ENEMY
## Damage multiplier for this region (e.g. a weak spot).
@export var damage_multiplier: float = 1.0
var invulnerable: bool = false
## The combatant that owns this hurtbox.
var entity: Node3D


func _ready() -> void:
	collision_layer = CombatTypes.LAYER_HURTBOX
	collision_mask = 0
	monitoring = false
	monitorable = true
	if entity == null:
		entity = owner as Node3D
	add_to_group(&"hurtboxes")


## Returns false if the hit was ignored (i-frames / disabled).
func receive_hit(hit: HitInfo) -> bool:
	if not monitorable:
		return false
	if invulnerable:
		hit.was_blocked_by_iframes = true
		return false
	hit.damage *= damage_multiplier
	hit_received.emit(hit)
	return true
