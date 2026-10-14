class_name LockOn
extends Node3D
## Target lock: toggle onto the best enemy in front, switch between targets,
## breaks when the target dies, gets too far or out of sight. Draws a marker.

var player: Player
var target: Combatant
var _marker: MeshInstance3D
var _t: float = 0.0


func _ready() -> void:
	_marker = MeshInstance3D.new()
	var m := PrismMesh.new()
	m.size = Vector3(0.32, 0.4, 0.08)
	_marker.mesh = m
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.82, 0.35)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.3)
	mat.emission_energy_multiplier = 3.0
	mat.no_depth_test = true
	mat.render_priority = 5
	_marker.material_override = mat
	_marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_marker.top_level = true
	_marker.visible = false
	add_child(_marker)


func toggle() -> void:
	if target != null:
		release()
	else:
		acquire()


func acquire() -> void:
	var best: Combatant = null
	var best_score := INF
	var aim := player.raw_aim_direction()
	for c in _candidates():
		var to := c.global_position - player.global_position
		to.y = 0.0
		var ang := absf(aim.signed_angle_to(to.normalized(), Vector3.UP))
		var score := to.length() + ang * 6.0
		if score < best_score:
			best_score = score
			best = c
	_set_target(best)


func release() -> void:
	_set_target(null)


func _set_target(c: Combatant) -> void:
	target = c
	_marker.visible = c != null
	if c != null:
		AudioManager.play_event(&"ui_move", null, 4.0)


## Cycles through candidates ordered by screen x position.
func switch_target(dir_sign: int) -> void:
	var cands := _candidates()
	if cands.is_empty():
		return
	var cam := player.input.camera
	var keyed: Array = []
	for c in cands:
		var x := c.global_position.x
		if cam != null:
			x = cam.unproject_position(c.global_position).x
		keyed.append([x, c])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var idx := -1
	for i in keyed.size():
		if keyed[i][1] == target:
			idx = i
			break
	var next := (idx + dir_sign + keyed.size()) % keyed.size() if idx >= 0 else 0
	_set_target(keyed[next][1] as Combatant)


func _candidates() -> Array[Combatant]:
	var out: Array[Combatant] = []
	var rng := GameState.balance.lock_on_range
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var c := n as Combatant
		if c == null or not c.is_targetable():
			continue
		if c.global_position.distance_to(player.global_position) > rng:
			continue
		if not _visible(c):
			continue
		out.append(c)
	return out


func _visible(c: Combatant) -> bool:
	var space := player.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(player.global_position + Vector3.UP * 1.2, c.aim_point(), CombatTypes.LAYER_WORLD)
	var hit := space.intersect_ray(q)
	return hit.is_empty()


func update_lock(dt: float) -> void:
	_t += dt
	if target == null:
		return
	if not is_instance_valid(target) or not target.is_targetable():
		# Auto-switch to the next closest enemy when the target dies.
		target = null
		var cands := _candidates()
		var best: Combatant = null
		var bd := 8.0
		for c in cands:
			var d := c.global_position.distance_to(player.global_position)
			if d < bd:
				bd = d
				best = c
		_set_target(best)
		return
	if target.global_position.distance_to(player.global_position) > GameState.balance.lock_on_break_range:
		release()
		return
	_marker.global_position = target.global_position + Vector3.UP * (target.lock_height + 0.9 + sin(_t * 5.0) * 0.08)
	_marker.rotation = Vector3(PI, _t * 2.5, 0.0)
