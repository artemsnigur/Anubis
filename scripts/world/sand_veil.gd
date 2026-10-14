class_name SandVeil
extends StaticBody3D
## Curtain of falling sand that seals the boss arena entrance during the fight.

const SHADER := preload("res://assets/shaders/sand_veil.gdshader")

@export var width: float = 6.0
@export var height: float = 5.5

var active: bool = false
var _shape: CollisionShape3D
var _mat: ShaderMaterial
var _curtain: MeshInstance3D
var _particles: GPUParticles3D


func _ready() -> void:
	collision_layer = CombatTypes.LAYER_GATE
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, height, 1.0)
	_shape.shape = bs
	_shape.position = Vector3(0, height * 0.5, 0)
	_shape.disabled = true
	add_child(_shape)
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_mat.set_shader_parameter(&"density", 0.0)
	_curtain = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(width, height)
	_curtain.mesh = q
	_curtain.material_override = _mat
	_curtain.position = Vector3(0, height * 0.5, 0)
	_curtain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_curtain)
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(width * 0.5, 0.1, 0.3)
	pm.direction = Vector3.DOWN
	pm.spread = 5.0
	pm.initial_velocity_min = 3.0
	pm.initial_velocity_max = 5.0
	pm.gravity = Vector3(0, -6, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.2
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.8, 1.0])
	g.colors = PackedColorArray([Color(0.9, 0.72, 0.42, 0.9), Color(0.85, 0.66, 0.38, 0.7), Color(0.8, 0.6, 0.35, 0.0)])
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	var qm := QuadMesh.new()
	qm.size = Vector2(0.18, 0.18)
	var sm := StandardMaterial3D.new()
	sm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	sm.vertex_color_use_as_albedo = true
	sm.albedo_texture = Vfx.soft_texture()
	qm.material = sm
	_particles = GPUParticles3D.new()
	_particles.amount = 160
	_particles.lifetime = 1.2
	_particles.process_material = pm
	_particles.draw_pass_1 = qm
	_particles.position = Vector3(0, height, 0)
	_particles.emitting = false
	_particles.visibility_aabb = AABB(Vector3(-width, -height - 1.0, -2), Vector3(width * 2.0, height + 2.0, 4))
	add_child(_particles)
	_curtain.visible = false


func raise_veil() -> void:
	if active:
		return
	active = true
	_shape.set_deferred(&"disabled", false)
	_curtain.visible = true
	_particles.emitting = true
	create_tween().tween_method(func(v: float) -> void: _mat.set_shader_parameter(&"density", v), 0.0, 1.0, 0.8)
	AudioManager.play_event(&"veil", global_position)
	Vfx.sand_burst(global_position + Vector3.UP, Vector3.UP, 30)


func drop_veil(instant: bool = false) -> void:
	active = false
	_shape.set_deferred(&"disabled", true)
	_particles.emitting = false
	if instant:
		_mat.set_shader_parameter(&"density", 0.0)
		_curtain.visible = false
		return
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: _mat.set_shader_parameter(&"density", v), 1.0, 0.0, 1.2)
	tw.tween_callback(func() -> void: _curtain.visible = false)
