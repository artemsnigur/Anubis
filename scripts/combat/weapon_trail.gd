class_name WeaponTrail
extends MeshInstance3D
## Ribbon trail between two points on the blade, rebuilt every frame into an
## ImmediateMesh. Samples are kept for `lifetime` seconds and subdivided with
## Catmull-Rom so fast swings stay smooth. Faded out by trail.gdshader.

const SHADER := preload("res://assets/shaders/trail.gdshader")

@export var lifetime: float = 0.22
@export var subdivisions: int = 4
@export var core_color: Color = Color(1.0, 0.88, 0.55)
@export var edge_color: Color = Color(0.2, 0.9, 0.85)

var base_point: Node3D
var tip_point: Node3D
var emitting: bool = false
var _samples: Array = []   # [time, base, tip]
var _time: float = 0.0
var _imesh: ImmediateMesh
var _mat: ShaderMaterial
## Current brightness of the ribbon (HDR, so it blooms).
var intensity: float = 3.2


func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_imesh = ImmediateMesh.new()
	mesh = _imesh
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter(&"core_color", core_color)
	_mat.set_shader_parameter(&"edge_color", edge_color)
	_mat.set_shader_parameter(&"intensity", intensity)
	material_override = _mat
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF


func setup(p_base: Node3D, p_tip: Node3D) -> void:
	base_point = p_base
	tip_point = p_tip


func set_intensity(value: float) -> void:
	intensity = value
	_mat.set_shader_parameter(&"intensity", value)


func _process(delta: float) -> void:
	_time += delta
	if emitting and base_point != null and tip_point != null:
		var b := base_point.get_global_transform_interpolated().origin
		var t := tip_point.get_global_transform_interpolated().origin
		if _samples.is_empty() or (_samples[_samples.size() - 1][2] as Vector3).distance_squared_to(t) > 0.0004:
			_samples.append([_time, b, t])
	while not _samples.is_empty() and _time - float(_samples[0][0]) > lifetime:
		_samples.pop_front()
	_rebuild()


func _rebuild() -> void:
	_imesh.clear_surfaces()
	if _samples.size() < 2:
		return
	var bases: Array[Vector3] = []
	var tips: Array[Vector3] = []
	var ages: Array[float] = []
	var n := _samples.size()
	for i in range(n - 1):
		var p0: Array = _samples[maxi(i - 1, 0)]
		var p1: Array = _samples[i]
		var p2: Array = _samples[i + 1]
		var p3: Array = _samples[mini(i + 2, n - 1)]
		for s in subdivisions:
			var u := float(s) / float(subdivisions)
			bases.append(_catmull(p0[1], p1[1], p2[1], p3[1], u))
			tips.append(_catmull(p0[2], p1[2], p2[2], p3[2], u))
			ages.append(lerpf(float(p1[0]), float(p2[0]), u))
	var last: Array = _samples[n - 1]
	bases.append(last[1])
	tips.append(last[2])
	ages.append(float(last[0]))
	_imesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, _mat)
	var alpha := 1.0 if emitting else 0.85
	for i in bases.size():
		var age := clampf((_time - ages[i]) / lifetime, 0.0, 1.0)
		_imesh.surface_set_color(Color(1, 1, 1, alpha))
		_imesh.surface_set_uv(Vector2(age, 0.0))
		_imesh.surface_add_vertex(bases[i])
		_imesh.surface_set_color(Color(1, 1, 1, alpha))
		_imesh.surface_set_uv(Vector2(age, 1.0))
		_imesh.surface_add_vertex(tips[i])
	_imesh.surface_end()


static func _catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: float) -> Vector3:
	var t2 := t * t
	var t3 := t2 * t
	return 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)


func clear() -> void:
	_samples.clear()
	_imesh.clear_surfaces()
