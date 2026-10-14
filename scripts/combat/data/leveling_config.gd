class_name LevelingConfig
extends Resource
## Ka costs and per-level bonuses.

@export var base_cost: int = 120
@export var cost_growth: float = 1.18
@export var hp_per_vitality: float = 12.0
@export var melee_bonus_per_strength: float = 0.08
@export var ranged_bonus_per_spirit: float = 0.12
@export var energy_gain_bonus_per_spirit: float = 0.12
@export var max_level_per_stat: int = 20


## Cost of going from player level `level` to `level + 1`.
func cost_for_level(level: int) -> int:
	var raw := float(base_cost) * pow(cost_growth, float(maxi(level - 1, 0)))
	return int(round(raw / 5.0) * 5.0)
