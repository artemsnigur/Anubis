class_name CombatTypes
extends RefCounted
## Shared enums and physics-layer constants.

enum Faction { PLAYER, ENEMY, HAZARD }

# Physics layer bits (see project.godot [layer_names]).
const LAYER_WORLD := 1
const LAYER_PLAYER := 2
const LAYER_ENEMY := 4
const LAYER_HURTBOX := 8
const LAYER_INTERACT := 16
const LAYER_GATE := 32
const LAYER_TRIGGER := 64
const LAYER_PICKUP := 128


## Hazards hit everyone; otherwise factions never hit themselves.
static func can_hit(attacker: Faction, target: Faction) -> bool:
	if attacker == Faction.HAZARD:
		return true
	return attacker != target
