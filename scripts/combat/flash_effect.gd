class_name FlashEffect
extends RefCounted
## Hit flash / telegraph tint for any model: temporarily sets an additive
## material_overlay on every mesh of the rig, fading out over the duration.

const SHADER := preload("res://assets/shaders/flash_overlay.gdshader")

var rig: CharacterRig
var _mat: ShaderMaterial
var _meshes: Array[GeometryInstance3D] = []
var _time_left: float = 0.0
var _duration: float = 0.1
var _peak: float = 1.0
var _applied: bool = false


func _init(p_rig: CharacterRig) -> void:
	rig = p_rig
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER


func flash(color: Color = Color.WHITE, duration: float = 0.12, peak: float = 1.0) -> void:
	_mat.set_shader_parameter(&"flash_color", color)
	_duration = maxf(duration, 0.01)
	_time_left = _duration
	_peak = peak
	if not _applied:
		_meshes = rig.get_meshes()
		for m in _meshes:
			if is_instance_valid(m):
				m.material_overlay = _mat
		_applied = true
	_mat.set_shader_parameter(&"amount", _peak)


func update(real_dt: float) -> void:
	if not _applied:
		return
	_time_left -= real_dt
	if _time_left <= 0.0:
		_clear()
		return
	var k := _time_left / _duration
	_mat.set_shader_parameter(&"amount", _peak * k * k)


func _clear() -> void:
	for m in _meshes:
		if is_instance_valid(m):
			m.material_overlay = null
	_applied = false
