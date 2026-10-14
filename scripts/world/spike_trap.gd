class_name SpikeTrap
extends Node3D
## Telegraphed pressure-plate trap. Stepping on the plate (gold eye inlay) clicks,
## dust rises and spike tips poke out of the holed floor, then the spikes shoot up.
## Hurts everyone (players and enemies) standing on the spike field.

enum Phase { IDLE, ARMED, ACTIVE, RETRACT, COOLDOWN }

@export var plate_offset: Vector3 = Vector3.ZERO
@export var field_size: Vector2 = Vector2(4.0, 3.0)
@export var field_offset: Vector3 = Vector3(0, 0, -2.5)
@export var telegraph_time: float = 0.55
@export var active_time: float = 0.6
@export var damage: float = 22.0

var phase: Phase = Phase.IDLE
var _t: float = 0.0
var _plate: Area3D
var _plate_mesh: MeshInstance3D
var _spikes: MultiMeshInstance3D
var _query := PhysicsShapeQueryParameters3D.new()
var _attack := AttackData.new()
var _hit: Array[Node] = []


func _ready() -> void:
	add_to_group(&"traps")
	_attack.id = &"spike_trap"
	_attack.damage = damage
	_attack.knockback = 6.0
	_attack.hitstop = 0.06
	_attack.shake = 0.3
	_attack.poise_damage = 20.0
	_attack.is_heavy = true
	# Pressure plate.
	_plate = Area3D.new()
	_plate.collision_layer = 0
	_plate.collision_mask = CombatTypes.LAYER_PLAYER | CombatTypes.LAYER_ENEMY
	_plate.position = plate_offset
	add_child(_plate)
	var pcs := CollisionShape3D.new()
	var pbs := BoxShape3D.new()
	pbs.size = Vector3(1.3, 0.8, 1.3)
	pcs.shape = pbs
	pcs.position = Vector3(0, 0.4, 0)
	_plate.add_child(pcs)
	_plate_mesh = Kit.mesh(self, PlaceholderRig.box(Vector3(1.3, 0.08, 1.3)), Mats.get_mat(&"basalt"), plate_offset + Vector3(0, 0.03, 0), Vector3.ZERO, Vector3.ONE, false)
	Kit.mesh(self, PlaceholderRig.cylinder(0.32, 0.32, 0.02, 16), Mats.get_mat(&"gold_world"), plate_offset + Vector3(0, 0.075, 0), Vector3.ZERO, Vector3.ONE, false)
	Kit.mesh(self, PlaceholderRig.sphere(0.12), Mats.get_mat(&"lapis"), plate_offset + Vector3(0, 0.075, 0), Vector3.ZERO, Vector3(1.0, 0.25, 1.0), false)
	# Spike field: dark holes + spikes (MultiMesh of cones).
	Kit.mesh(self, PlaceholderRig.box(Vector3(field_size.x, 0.02, field_size.y)), Mats.get_mat(&"basalt"), field_offset + Vector3(0, 0.005, 0), Vector3.ZERO, Vector3.ONE, false)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.08
	cone.height = 0.9
	cone.radial_segments = 6
	cone.rings = 1
	mm.mesh = cone
	var nx := int(field_size.x / 0.5)
	var nz := int(field_size.y / 0.5)
	mm.instance_count = nx * nz
	var i := 0
	for x in nx:
		for z in nz:
			var p := field_offset + Vector3(-field_size.x * 0.5 + (float(x) + 0.5) * field_size.x / float(nx), 0.0, -field_size.y * 0.5 + (float(z) + 0.5) * field_size.y / float(nz))
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
			i += 1
	_spikes = MultiMeshInstance3D.new()
	_spikes.multimesh = mm
	_spikes.material_override = Mats.get_mat(&"bronze")
	_spikes.position.y = -0.85
	add_child(_spikes)
	var shape := BoxShape3D.new()
	shape.size = Vector3(field_size.x, 1.2, field_size.y)
	_query.shape = shape
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	_query.collision_mask = CombatTypes.LAYER_HURTBOX


func reset() -> void:
	phase = Phase.IDLE
	_t = 0.0
	_spikes.position.y = -0.85


func _physics_process(delta: float) -> void:
	_t += delta
	match phase:
		Phase.IDLE:
			for b in _plate.get_overlapping_bodies():
				if b is Combatant and not (b as Combatant).is_dead:
					_arm()
					break
		Phase.ARMED:
			if _t >= telegraph_time:
				_fire()
		Phase.ACTIVE:
			_damage_scan()
			if _t >= active_time:
				phase = Phase.RETRACT
				_t = 0.0
				create_tween().tween_property(_spikes, "position:y", -0.85, 0.4).set_ease(Tween.EASE_IN)
		Phase.RETRACT:
			if _t >= 0.4:
				phase = Phase.COOLDOWN
				_t = 0.0
		Phase.COOLDOWN:
			if _t >= 1.2:
				phase = Phase.IDLE
				_t = 0.0


func _arm() -> void:
	phase = Phase.ARMED
	_t = 0.0
	AudioManager.play_event(&"spike_click", global_transform * plate_offset)
	create_tween().tween_property(_plate_mesh, "position:y", 0.0, 0.08)
	create_tween().tween_property(_spikes, "position:y", -0.7, 0.15)
	var c := global_transform * field_offset
	for k in 3:
		Vfx.dust(c + Vector3(randf_range(-field_size.x, field_size.x) * 0.4, 0, randf_range(-field_size.y, field_size.y) * 0.4), 4, 0.9)


func _fire() -> void:
	phase = Phase.ACTIVE
	_t = 0.0
	_hit.clear()
	create_tween().tween_property(_plate_mesh, "position:y", 0.03, 0.3)
	create_tween().tween_property(_spikes, "position:y", 0.0, 0.06).set_ease(Tween.EASE_OUT)
	var c := global_transform * field_offset
	AudioManager.play_event(&"spikes", c)
	Vfx.sand_burst(c + Vector3.UP * 0.3, Vector3.UP, 16)
	CameraShake.add_trauma_at(0.2, c, 12.0)


func _damage_scan() -> void:
	var space := get_world_3d().direct_space_state
	_query.transform = Transform3D(global_basis, global_transform * (field_offset + Vector3.UP * 0.6))
	for r: Dictionary in space.intersect_shape(_query, 16):
		var hb := r.get("collider") as HurtboxComponent
		if hb == null or hb.entity == null or _hit.has(hb.entity):
			continue
		_hit.append(hb.entity)
		var h := HitInfo.from_attack(_attack, null, CombatTypes.Faction.HAZARD)
		var d := hb.entity.global_position - global_transform * field_offset
		d.y = 0.0
		h.direction = d.normalized() if d.length() > 0.1 else Vector3.FORWARD
		h.position = hb.global_position + Vector3.UP * 0.3
		if hb.receive_hit(h):
			Vfx.hit_sparks(h.position, Vector3.UP, true)
