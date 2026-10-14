class_name Shockwave
extends Node3D
## Expanding ground ring. Hits a target once when the front of the ring passes it;
## dodge i-frames let the player roll through it.

var attack: AttackData
var source: Node3D
var faction: CombatTypes.Faction = CombatTypes.Faction.ENEMY
var from_radius: float = 1.0
var to_radius: float = 8.0
var duration: float = 0.55
var band: float = 0.9
var _t: float = 0.0
var _hit: Array[Node] = []


func setup(p_attack: AttackData, p_source: Node3D, p_to_radius: float, p_duration: float = 0.55) -> void:
	attack = p_attack
	source = p_source
	to_radius = p_to_radius
	duration = p_duration


func _ready() -> void:
	add_to_group(&"transient")
	Vfx.ring(global_position, from_radius, to_radius, duration, Color(1.0, 0.7, 0.3), 0.1)
	Vfx.ring(global_position, from_radius * 0.6, to_radius * 0.75, duration * 1.3, Color(0.9, 0.6, 0.3), 0.25)
	for i in 10:
		var a := TAU * float(i) / 10.0
		Vfx.sand_burst(global_position + Vector3(cos(a), 0.2, sin(a)) * 1.2, Vector3(cos(a), 0.3, sin(a)), 8)


func _physics_process(delta: float) -> void:
	_t += delta
	var r := lerpf(from_radius, to_radius, clampf(_t / duration, 0.0, 1.0))
	for n in get_tree().get_nodes_in_group(&"hurtboxes"):
		var hb := n as HurtboxComponent
		if hb == null or hb.entity == null or hb.entity == source or _hit.has(hb.entity):
			continue
		if not CombatTypes.can_hit(faction, hb.faction):
			continue
		var p := hb.entity.global_position
		if absf(p.y - global_position.y) > 1.5:
			continue
		var d := Vector2(p.x - global_position.x, p.z - global_position.z).length()
		if absf(d - r) < band:
			_hit.append(hb.entity)
			var h := HitInfo.from_attack(attack, source, faction, GameState.balance.enemy_damage_mult * 0.6)
			var dir := Vector3(p.x - global_position.x, 0.0, p.z - global_position.z)
			h.direction = dir.normalized() if dir.length() > 0.01 else Vector3.FORWARD
			h.position = p + Vector3.UP * 0.6
			h.is_projectile = true
			hb.receive_hit(h)
	if _t >= duration:
		queue_free()
