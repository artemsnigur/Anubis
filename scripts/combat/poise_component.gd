class_name PoiseComponent
extends Node
## Poise meter. Damage fills nothing - it drains poise; at zero the owner is staggered.
## Regenerates after a delay without poise damage.

signal broken
signal changed(current: float, maximum: float)

@export var max_poise: float = 30.0
@export var regen_delay: float = 2.5
@export var regen_rate: float = 15.0
var current: float = 30.0
var _since_damage: float = 0.0
var _locked: bool = false


func _ready() -> void:
	current = max_poise


func setup(maximum: float, delay: float, rate: float) -> void:
	max_poise = maximum
	regen_delay = delay
	regen_rate = rate
	current = maximum
	changed.emit(current, max_poise)


## Returns true when this damage broke the poise.
func apply(amount: float) -> bool:
	if _locked or amount <= 0.0 or max_poise <= 0.0:
		return false
	_since_damage = 0.0
	current -= amount
	if current <= 0.0:
		current = 0.0
		_locked = true
		changed.emit(current, max_poise)
		broken.emit()
		return true
	changed.emit(current, max_poise)
	return false


## Called when the stagger ends.
func restore() -> void:
	_locked = false
	current = max_poise
	_since_damage = 0.0
	changed.emit(current, max_poise)


func tick(dt: float) -> void:
	if _locked:
		return
	_since_damage += dt
	if _since_damage >= regen_delay and current < max_poise:
		current = minf(max_poise, current + regen_rate * dt)
		changed.emit(current, max_poise)


func ratio() -> float:
	return current / max_poise if max_poise > 0.0 else 1.0
