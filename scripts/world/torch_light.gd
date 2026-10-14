class_name TorchLight
extends OmniLight3D
## Flickering fire light (noise-driven energy and a tiny position wobble).

@export var base_energy: float = 2.2
@export var flicker: float = 0.35
@export var speed: float = 9.0

var _noise := FastNoiseLite.new()
var _t: float = 0.0
var _origin: Vector3


func _ready() -> void:
	_noise.seed = randi()
	_noise.frequency = 0.8
	_t = randf() * 100.0
	_origin = position


func _process(delta: float) -> void:
	_t += delta * speed
	var n := _noise.get_noise_1d(_t)
	light_energy = base_energy * (1.0 + n * flicker)
	position = _origin + Vector3(_noise.get_noise_1d(_t + 40.0), _noise.get_noise_1d(_t + 80.0) * 0.5, _noise.get_noise_1d(_t + 120.0)) * 0.04
