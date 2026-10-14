class_name EnemyState
extends State
## Base for enemy states: typed access to the enemy and a think timer.

var enemy: EnemyBase
var _think: float = 0.0


func on_setup() -> void:
	enemy = actor as EnemyBase


## Returns true every `think_interval` seconds (cheap decisions).
func think(dt: float) -> bool:
	_think -= dt
	if _think <= 0.0:
		_think = enemy.data.think_interval * randf_range(0.8, 1.2)
		return true
	return false
