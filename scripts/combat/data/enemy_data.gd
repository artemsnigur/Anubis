class_name EnemyData
extends Resource
## Balance data of an enemy type.

@export var display_name: String = "Enemy"

@export_group("Vitals")
@export var max_hp: float = 60.0
@export var max_poise: float = 30.0
@export var poise_regen_delay: float = 2.5
@export var poise_regen_rate: float = 15.0
## Damage multiplier while staggered (the "punish window").
@export var stagger_damage_mult: float = 1.5
@export var flinch_duration: float = 0.25
@export var stagger_duration: float = 2.0
## 0 = full knockback, 1 = immovable.
@export_range(0.0, 1.0) var knockback_resist: float = 0.0
## Hits during an attack do not interrupt it (poise break still does).
@export var hyper_armor: bool = false
@export var ka_reward: int = 40

@export_group("Movement")
@export var walk_speed: float = 2.0
@export var run_speed: float = 4.0
@export var acceleration: float = 20.0
@export var turn_speed_deg: float = 360.0

@export_group("Perception")
@export var detect_radius: float = 10.0
@export var lose_radius: float = 22.0
## Max distance from the spawn point before the enemy gives up and returns.
@export var leash_radius: float = 26.0
@export var alert_time: float = 0.45

@export_group("Combat AI")
@export var strafe_radius: float = 4.0
@export var strafe_speed: float = 2.0
@export var uses_tokens: bool = true
@export var think_interval: float = 0.25
@export var attacks: Array[EnemyAttackData] = []
## Chance to sidestep a player attack (Jackal).
@export_range(0.0, 1.0) var evade_chance: float = 0.0
@export var evade_cooldown: float = 2.5
## Distance under which the enemy retreats (Cobra). 0 = never.
@export var retreat_radius: float = 0.0
