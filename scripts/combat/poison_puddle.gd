extends Node3D
## Venom puddle left by the Cobra Priestess spit: damages the player standing in it
## every tick for a few seconds (damage over time, no flinch).

@export var radius: float = 1.4
@export var duration: float = 4.0
@export var tick: float = 0.5
@export var damage_per_tick: float = 4.0

var _t: float = 0.0
var _tick_t: float = 0.0
var _mat: StandardMaterial3D
var _mesh: MeshInstance3D
var _query := PhysicsShapeQueryParameters3D.new()
var _attack := AttackData.new()


func _ready() -> void:
	add_to_group(&"transient")
	_mesh = MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = 0.02
	c.radial_segments = 24
	_mesh.mesh = c
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.3, 0.75, 0.15, 0.75)
	_mat.emission_enabled = true
	_mat.emission = Color(0.35, 0.9, 0.15)
	_mat.emission_energy_multiplier = 1.4
	_mat.roughness = 0.1
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mesh.material_override = _mat
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mesh.scale = Vector3(0.2, 1.0, 0.2)
	add_child(_mesh)
	create_tween().tween_property(_mesh, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var shape := CylinderShape3D.new()
	shape.radius = radius
	shape.height = 1.2
	_query.shape = shape
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	_query.collision_mask = CombatTypes.LAYER_HURTBOX
	_attack.id = &"venom_puddle"
	_attack.damage = damage_per_tick
	_attack.knockback = 0.0
	_attack.hitstop = 0.0
	_attack.shake = 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	_tick_t -= delta
	if _tick_t <= 0.0 and _t < duration:
		_tick_t = tick
		_damage_tick()
		Vfx.motes(global_position + Vector3(randf_range(-0.6, 0.6), 0.1, randf_range(-0.6, 0.6)), 2)
	if _t > duration - 0.6:
		var k := clampf((duration - _t) / 0.6, 0.0, 1.0)
		_mat.albedo_color.a = 0.75 * k
		_mat.emission_energy_multiplier = 1.4 * k
	if _t >= duration:
		queue_free()


func _damage_tick() -> void:
	var space := get_world_3d().direct_space_state
	_query.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * 0.5)
	for r: Dictionary in space.intersect_shape(_query, 8):
		var hb := r.get("collider") as HurtboxComponent
		if hb == null or hb.faction != CombatTypes.Faction.PLAYER:
			continue
		var h := HitInfo.from_attack(_attack, null, CombatTypes.Faction.ENEMY)
		h.is_dot = true
		h.direction = Vector3.FORWARD
		h.position = hb.global_position
		hb.receive_hit(h)
