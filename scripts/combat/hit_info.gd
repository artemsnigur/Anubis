class_name HitInfo
extends RefCounted
## Everything a hurtbox needs to know about an incoming hit.

var attacker: Node3D
var attack: AttackData
var faction: CombatTypes.Faction = CombatTypes.Faction.ENEMY
var damage: float = 0.0
var poise_damage: float = 0.0
var knockback: float = 0.0
## Horizontal, normalised direction from attacker to target.
var direction: Vector3 = Vector3.FORWARD
var position: Vector3 = Vector3.ZERO
var hitstop: float = 0.06
var shake: float = 0.2
var is_heavy: bool = false
var is_projectile: bool = false
var is_grab: bool = false
## Damage over time (puddles, quicksand): no flinch, no hitstop, no knockback.
var is_dot: bool = false
## Filled by the receiver.
var was_blocked_by_iframes: bool = false
var caused_stagger: bool = false
var killed: bool = false


static func from_attack(p_attack: AttackData, p_attacker: Node3D, p_faction: CombatTypes.Faction, mult: float = 1.0) -> HitInfo:
	var h := HitInfo.new()
	h.attack = p_attack
	h.attacker = p_attacker
	h.faction = p_faction
	h.damage = p_attack.damage * mult
	h.poise_damage = p_attack.poise_damage * mult
	h.knockback = p_attack.knockback
	h.hitstop = p_attack.hitstop
	h.shake = p_attack.shake
	h.is_heavy = p_attack.is_heavy
	return h
