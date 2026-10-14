class_name BalanceConfig
extends Resource
## Global combat-feel and fairness parameters.

@export_group("Input")
@export var input_buffer_time: float = 0.15

@export_group("Aim assist")
@export var aim_assist_enabled: bool = true
## Full cone angle (degrees) in which aim assist looks for targets.
@export var aim_assist_angle: float = 60.0
@export var aim_assist_range: float = 4.0
## 0..1: how strongly the attack direction is rotated toward the target.
@export_range(0.0, 1.0) var aim_assist_strength: float = 0.65
## Extra step toward the target (metres, max).
@export var aim_assist_step: float = 0.8
## Preferred distance to stop the step at.
@export var aim_assist_stop_distance: float = 1.3

@export_group("Hitstop / feel")
@export var hitstop_multiplier: float = 1.0
@export var max_hitstop: float = 0.12
@export var player_hurt_hitstop: float = 0.08
@export var shake_on_player_hurt: float = 0.45

@export_group("AI fairness")
@export var max_attack_tokens: int = 2
@export var token_cooldown: float = 0.35
@export var enemy_damage_mult: float = 1.0

@export_group("Lock-on")
@export var lock_on_range: float = 16.0
@export var lock_on_break_range: float = 22.0
