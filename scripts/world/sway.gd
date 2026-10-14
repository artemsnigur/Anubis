extends Node3D
## Gentle wind sway for plants (rotates each child stem around its base).

@export var amplitude_deg: float = 4.0
@export var speed: float = 1.3

var _t: float = 0.0
var _phases: Array[float] = []


func _ready() -> void:
	for c in get_children():
		_phases.append(randf() * TAU)


func _process(delta: float) -> void:
	_t += delta * speed
	var i := 0
	for c in get_children():
		if c is Node3D and i < _phases.size():
			var n := c as Node3D
			n.rotation_degrees.z = sin(_t + _phases[i]) * amplitude_deg
			n.rotation_degrees.x = cos(_t * 0.7 + _phases[i]) * amplitude_deg * 0.5
		i += 1
