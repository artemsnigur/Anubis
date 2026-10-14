extends MeshInstance3D
## Cheap flame animation: noisy scale wobble of an emissive cone.

var _t: float = 0.0
var _base: Vector3


func _ready() -> void:
	_t = randf() * 10.0
	_base = scale


func _process(delta: float) -> void:
	_t += delta
	var s := 1.0 + sin(_t * 17.0) * 0.08 + sin(_t * 29.0 + 1.3) * 0.06
	scale = _base * Vector3(1.0 + sin(_t * 23.0) * 0.06, s, 1.0 + cos(_t * 19.0) * 0.06)
	rotation.y = _t * 2.0
