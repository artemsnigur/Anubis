class_name HealthComponent
extends Node
## Hit points with damage / heal / death signals.

signal changed(current: float, maximum: float)
signal damaged(amount: float)
signal healed(amount: float)
signal died

@export var max_health: float = 100.0
var current: float = 100.0
var dead: bool = false


func _ready() -> void:
	current = max_health


func setup(maximum: float, fill: bool = true) -> void:
	max_health = maximum
	if fill:
		current = maximum
		dead = false
	current = minf(current, max_health)
	changed.emit(current, max_health)


func damage(amount: float) -> float:
	if dead or amount <= 0.0:
		return 0.0
	var dealt := minf(amount, current)
	current -= dealt
	damaged.emit(dealt)
	changed.emit(current, max_health)
	if current <= 0.0:
		current = 0.0
		dead = true
		died.emit()
	return dealt


func heal(amount: float) -> void:
	if dead or amount <= 0.0:
		return
	var before := current
	current = minf(current + amount, max_health)
	healed.emit(current - before)
	changed.emit(current, max_health)


func revive_full() -> void:
	dead = false
	current = max_health
	changed.emit(current, max_health)


func ratio() -> float:
	return current / max_health if max_health > 0.0 else 0.0
