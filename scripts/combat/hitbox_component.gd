class_name HitboxComponent
extends Area3D
## Deals hits while active. Each activation hits a given hurtbox (entity) at most once.
## Uses an immediate shape query every physics frame, so resizing/moving the box at
## activation time is exact (no one-frame overlap lag).

signal hit_landed(target: Node3D, hit: HitInfo)

@export var faction: CombatTypes.Faction = CombatTypes.Faction.PLAYER
var attacker: Node3D
var attack: AttackData
var damage_mult: float = 1.0
var active: bool = false
## Optional custom direction provider; default = attacker -> target.
var radial: bool = false
var _hit_entities: Array[Node] = []
var _shape_node: CollisionShape3D
var _query := PhysicsShapeQueryParameters3D.new()


func _ready() -> void:
	collision_layer = 0
	collision_mask = CombatTypes.LAYER_HURTBOX
	monitoring = false
	monitorable = false
	if attacker == null:
		attacker = owner as Node3D
	for c in get_children():
		if c is CollisionShape3D:
			_shape_node = c
			break
	if _shape_node == null:
		_shape_node = CollisionShape3D.new()
		_shape_node.shape = BoxShape3D.new()
		add_child(_shape_node)
	_query.collide_with_areas = true
	_query.collide_with_bodies = false
	_query.collision_mask = CombatTypes.LAYER_HURTBOX
	add_to_group(&"hitboxes")


## Starts an activation using the attack's box size/offset.
func activate(p_attack: AttackData, mult: float = 1.0, use_attack_shape: bool = true) -> void:
	attack = p_attack
	damage_mult = mult
	_hit_entities.clear()
	if use_attack_shape and p_attack != null:
		var box := _shape_node.shape as BoxShape3D
		if box == null:
			box = BoxShape3D.new()
			_shape_node.shape = box
		box.size = p_attack.hitbox_size
		position = Vector3(0.0, p_attack.hitbox_height, -p_attack.hitbox_forward)
	active = true
	_scan()


func deactivate() -> void:
	active = false


func set_sphere(radius: float, local_pos: Vector3) -> void:
	var sphere := _shape_node.shape as SphereShape3D
	if sphere == null:
		sphere = SphereShape3D.new()
		_shape_node.shape = sphere
	sphere.radius = radius
	position = local_pos


func shape_node() -> CollisionShape3D:
	return _shape_node


func _physics_process(_delta: float) -> void:
	if active:
		_scan()


func _scan() -> void:
	if not is_inside_tree() or attack == null:
		return
	var space := get_world_3d().direct_space_state
	_query.shape = _shape_node.shape
	_query.transform = _shape_node.global_transform
	var results := space.intersect_shape(_query, 24)
	for r: Dictionary in results:
		var hb := r.get("collider") as HurtboxComponent
		if hb == null or hb.entity == null or hb.entity == attacker:
			continue
		if not CombatTypes.can_hit(faction, hb.faction):
			continue
		if _hit_entities.has(hb.entity):
			continue
		_hit_entities.append(hb.entity)
		_deliver(hb)


func _deliver(hb: HurtboxComponent) -> void:
	var hit := HitInfo.from_attack(attack, attacker, faction, damage_mult)
	var from := attacker.global_position if attacker != null else global_position
	var to := hb.entity.global_position
	var dir := to - from
	dir.y = 0.0
	if dir.length_squared() < 0.0001:
		dir = -global_basis.z
		dir.y = 0.0
	hit.direction = dir.normalized()
	hit.position = hb.global_position.lerp(global_position, 0.35) + Vector3.UP * 0.2
	if hb.receive_hit(hit):
		hit_landed.emit(hb.entity, hit)


func already_hit(entity: Node) -> bool:
	return _hit_entities.has(entity)
