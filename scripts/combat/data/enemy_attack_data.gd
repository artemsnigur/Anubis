class_name EnemyAttackData
extends AttackData
## Enemy attack: adds AI selection data, telegraph and special movement.

enum MoveType { NONE, LUNGE, CHARGE, LEAP, GRAB, PROJECTILE, SPIN, BURROW, SUMMON, ROAR }
enum Telegraph { GLINT, FLASH, GROUND_CIRCLE, ROAR }

@export_group("AI selection")
@export var range_min: float = 0.0
@export var range_max: float = 2.5
## Target must be inside this angle (degrees, full cone) in front to start the attack.
@export var angle_max: float = 70.0
@export var cooldown: float = 1.5
@export var weight: float = 1.0
## Minimum boss phase that unlocks this attack (1 or 2).
@export var phase_min: int = 1
## Only usable in phase 1 if true (replaced by faster variants in phase 2).
@export var phase_one_only: bool = false

@export_group("Telegraph")
@export var telegraph: Telegraph = Telegraph.GLINT
## How far before the active frame the glint/flash fires.
@export var telegraph_lead: float = 0.3
## Turning speed (deg/s) while winding up: how much the enemy tracks the player.
@export var tracking_deg: float = 240.0

@export_group("Special movement")
@export var move_type: MoveType = MoveType.LUNGE
@export var move_speed: float = 8.0
@export var move_duration: float = 0.2
## Turn rate (deg/s) during a charge.
@export var charge_turn_deg: float = 70.0
@export var shockwave_radius: float = 0.0
@export var spawn_count: int = 0

@export_group("Combo")
## Attack executed immediately after this one's active phase (combo chain).
@export var combo_next: EnemyAttackData
## Phase-2 override of combo_next (Ammit's faster combos). Null = use combo_next.
@export var combo_next_phase2: EnemyAttackData
## Recovery used when chaining into combo_next (instead of the full recovery).
@export var combo_gap: float = 0.15
