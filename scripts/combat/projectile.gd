class_name Projectile
extends Node3D
## Simple swept projectile.
##  RA    - the player's "Eye of Ra": fast straight sun bolt.
##  VENOM - Cobra Priestess spit: lobbed arc toward a point, leaves a poison puddle.

enum Kind { RA, VENOM }

const PUDDLE := preload("res://scenes/combat/poison_puddle.tscn")

var kind: Kind = Kind.RA
var attack: AttackData
var shooter: Node3D
var faction: CombatTypes.Faction = CombatTypes.Faction.PLAYER
var damage_mult: float = 1.0
var velocity: Vector3 = Vector3.ZERO
var gravity_y: float = 0.0
var max_distance: float = 20.0
var radius: float = 0.4
var _travelled: float = 0.0
var _done: bool = false
var _query := PhysicsShapeQueryParameters3D.new()
var _light: OmniLight3D
var _visual: Node3D
var _age: float = 0.0


func setup_ra(p_shooter: Node3D, p_attack: AttackData, mult: float, dir: Vector3, speed: float, p_range: float) -> void:
	kind = Kind.RA
	shooter = p_shooter
	attack = p_attack
	faction = CombatTypes.Faction.PLAYER
	damage_mult = mult
	velocity = dir.normalized() * speed
	max_distance = p_range
	radius = 0.45


## Ballistic lob from `from` that lands on `target` after travelling at ~`speed`.
func setup_venom(p_shooter: Node3D, p_attack: AttackData, from: Vector3, target: Vector3, speed: float) -> void:
	kind = Kind.VENOM
	shooter = p_shooter
	attack = p_attack
	faction = CombatTypes.Faction.ENEMY
	var flat := Vector3(target.x - from.x, 0.0, target.z - from.z)
	var t := clampf(flat.length() / speed, 0.35, 1.4)
	gravity_y = 18.0
	var vy := (target.y - from.y + 0.5 * gravity_y * t * t) / t
	velocity = flat / t + Vector3.UP * vy
	max_distance = 40.0
	radius = 0.35


func _ready() -> void:
	_visual = Node3D.new()
	add_child(_visual)
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.22 if kind == Kind.RA else 0.17
	s.height = s.radius * 2.0
	mi.mesh = s
	mi.material_override = Mats.get_mat(&"sun" if kind == Kind.RA else &"venom")
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_visual.add_child(mi)
	if kind == Kind.RA:
		# Rays of the sun disc.
		var ring := MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.28
		t.outer_radius = 0.36
		ring.mesh = t
		ring.material_override = Mats.get_mat(&"sun")
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		ring.rotation_degrees = Vector3(90, 0, 0)
		_visual.add_child(ring)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.75, 0.35) if kind == Kind.RA else Color(0.45, 1.0, 0.3)
	_light.light_energy = 3.0 if kind == Kind.RA else 1.5
	_light.omni_range = 5.0 if kind == Kind.RA else 3.0
	add_child(_light)
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	_query.shape = sphere
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	_query.collision_mask = CombatTypes.LAYER_HURTBOX


func _physics_process(delta: float) -> void:
	if _done:
		return
	_age += delta
	velocity.y -= gravity_y * delta
	var from := global_position
	var to := from + velocity * delta
	var space := get_world_3d().direct_space_state
	# Hurtboxes.
	_query.transform = Transform3D(Basis.IDENTITY, to)
	for r: Dictionary in space.intersect_shape(_query, 8):
		var hb := r.get("collider") as HurtboxComponent
		if hb == null or hb.entity == null or hb.entity == shooter:
			continue
		if not CombatTypes.can_hit(faction, hb.faction):
			continue
		if _hit_hurtbox(hb, to):
			return
	# World geometry.
	var rq := PhysicsRayQueryParameters3D.create(from, to, CombatTypes.LAYER_WORLD | CombatTypes.LAYER_GATE)
	var hit := space.intersect_ray(rq)
	if not hit.is_empty():
		_impact(hit["position"], hit["normal"])
		return
	global_position = to
	_travelled += (to - from).length()
	_visual.rotation.z += delta * 8.0
	if kind == Kind.RA and int(_age * 60.0) % 3 == 0:
		Vfx.motes(to, 2)
	if _travelled >= max_distance or _age > 4.0:
		_impact(to, Vector3.UP)


func _hit_hurtbox(hb: HurtboxComponent, at: Vector3) -> bool:
	var h := HitInfo.from_attack(attack, shooter, faction, damage_mult)
	h.is_projectile = true
	var dir := velocity
	dir.y = 0.0
	h.direction = dir.normalized() if dir.length_squared() > 0.001 else Vector3.FORWARD
	h.position = at
	var accepted := hb.receive_hit(h)
	if h.was_blocked_by_iframes:
		# Dodged through: keep flying.
		return false
	if accepted and shooter != null and is_instance_valid(shooter) and shooter is Combatant:
		(shooter as Combatant)._on_hit_landed(hb.entity, h)
	_impact(at, -h.direction)
	return true


func _impact(at: Vector3, normal: Vector3) -> void:
	_done = true
	if kind == Kind.RA:
		Vfx.hit_sparks(at, normal, true)
		Vfx.motes(at, 14)
		Vfx.ring(Vector3(at.x, _ground_y(at), at.z), 0.2, 2.0, 0.3, Color(1.0, 0.75, 0.3))
		AudioManager.play_event(&"ra_impact", at)
	else:
		Vfx.venom_splash(at)
		AudioManager.play_event(&"puddle", at)
		var puddle := PUDDLE.instantiate() as Node3D
		get_tree().current_scene.add_child(puddle)
		puddle.global_position = Vector3(at.x, _ground_y(at) + 0.03, at.z)
		puddle.reset_physics_interpolation()
	queue_free()


func _ground_y(at: Vector3) -> float:
	var space := get_world_3d().direct_space_state
	var rq := PhysicsRayQueryParameters3D.create(at + Vector3.UP * 0.5, at + Vector3.DOWN * 6.0, CombatTypes.LAYER_WORLD)
	var hit := space.intersect_ray(rq)
	return (hit["position"] as Vector3).y if not hit.is_empty() else at.y
