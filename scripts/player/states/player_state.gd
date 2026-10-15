class_name PlayerState
extends State
## Base for player states: typed access to the Player plus the cancel-window API.
## accepts(kind) tells whether a new "move" / "attack" / "dodge" input would be taken
## right now (used by the states themselves, the FeelProbe lockout measurement and the
## F3 window timeline); windows() describes the timeline for the overlay.

## Tolerance for window times: the state clock is a sum of float ticks, so a window at
## exactly 0.2 s must open on tick 12 even if the sum is 0.19999.
const EPS := 0.0005

var player: Player


func on_setup() -> void:
	player = actor as Player


## True once the state clock has reached `t` (with EPS tolerance).
func reached(t: float) -> bool:
	return time_in_state + EPS >= t


func accepts(_kind: StringName) -> bool:
	return false


## {"name", "t", "total", "phases": [[duration, Color], ...], "marks": {kind: time}} or {}.
func windows() -> Dictionary:
	return {}
