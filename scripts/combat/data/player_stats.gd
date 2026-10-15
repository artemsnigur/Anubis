class_name PlayerStats
extends Resource
## Base player balance (before levels). Movement feel, dodge timing and cancel windows
## live in FeelPreset (resources/feel/).

@export_group("Vitals")
@export var max_hp: float = 100.0
@export var stamina_enabled: bool = true
@export var max_stamina: float = 100.0
@export var stamina_regen: float = 55.0
@export var stamina_regen_delay: float = 0.45
@export var max_energy: int = 4
@export var ankh_charges: int = 3

@export_group("Movement")
@export var run_speed: float = 6.0
@export var heal_move_speed: float = 1.6

@export_group("Dodge")
@export var dodge_stamina: float = 22.0

@export_group("Attacks")
@export var light_attacks: Array[AttackData] = []
@export var heavy_attack: AttackData
@export var ranged_attack: AttackData
@export var heavy_max_charge: float = 0.8
@export var heavy_charge_damage_mult: float = 1.8
@export var ranged_projectile_speed: float = 26.0
@export var ranged_range: float = 22.0

@export_group("Heal")
@export var heal_duration: float = 0.7
@export var heal_apply_time: float = 0.45
@export_range(0.0, 1.0) var heal_fraction: float = 0.45

@export_group("Hit reaction")
@export var hurt_duration: float = 0.32
@export var heavy_hurt_duration: float = 0.6
@export var hurt_iframes: float = 0.25
