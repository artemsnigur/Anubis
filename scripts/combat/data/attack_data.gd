class_name AttackData
extends Resource
## One attack's timing and damage profile. Shared by the player and enemies.
## Timings drive the generated placeholder animations and the animation events
## (hitbox on/off) injected into imported animations, so editing them here retimes everything.

@export var id: StringName = &"attack"
## Logical animation name (see AnimationMap).
@export var anim: StringName = &"light_1"

@export_group("Timing (seconds)")
@export var windup: float = 0.1
@export var active: float = 0.08
@export var recovery: float = 0.2
## Time into recovery after which a buffered follow-up attack starts.
@export var chain_delay: float = 0.04
## Time into recovery after which a dodge can cancel the attack.
@export var cancel_delay: float = 0.0

@export_group("Damage")
@export var damage: float = 10.0
@export var poise_damage: float = 10.0
@export var knockback: float = 3.0
@export var hitstop: float = 0.06
@export var shake: float = 0.22
@export var stamina_cost: float = 12.0
## Solar energy (in charges) gained when this attack lands.
@export var energy_gain: float = 0.25
@export var is_heavy: bool = false

@export_group("Movement")
## Forward step taken during the end of windup / start of active.
@export var lunge_distance: float = 0.5

@export_group("Hitbox")
@export var hitbox_size: Vector3 = Vector3(2.2, 1.4, 1.8)
## Distance of the hitbox centre in front of the attacker.
@export var hitbox_forward: float = 1.0
@export var hitbox_height: float = 0.9


func total_time() -> float:
	return windup + active + recovery
