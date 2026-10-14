extends CanvasLayer
## Debug tools.
##  F3 - overlay with FPS and the current state of every state machine nearby.
##  F4 - draws hitboxes (red when active) and hurtboxes (green, blue = invulnerable).

var overlay_visible: bool = false
var hitboxes_visible: bool = false
var _label: Label
var _panel: PanelContainer
var _viz: Dictionary = {}   # Area3D -> MeshInstance3D
var _mat_hit_on: StandardMaterial3D
var _mat_hit_off: StandardMaterial3D
var _mat_hurt: StandardMaterial3D
var _mat_hurt_inv: StandardMaterial3D


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.6)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	_panel.add_theme_stylebox_override(&"panel", sb)
	_panel.position = Vector2(12, 12)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_panel)
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", 15)
	_label.add_theme_color_override(&"font_color", Color(0.85, 1.0, 0.85))
	_panel.add_child(_label)
	_panel.visible = false
	_mat_hit_on = _viz_mat(Color(1.0, 0.1, 0.1, 0.45))
	_mat_hit_off = _viz_mat(Color(1.0, 0.6, 0.1, 0.08))
	_mat_hurt = _viz_mat(Color(0.1, 1.0, 0.3, 0.25))
	_mat_hurt_inv = _viz_mat(Color(0.2, 0.4, 1.0, 0.35))


func _viz_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.no_depth_test = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay"):
		overlay_visible = not overlay_visible
		_panel.visible = overlay_visible
	elif event.is_action_pressed(&"debug_hitboxes"):
		hitboxes_visible = not hitboxes_visible
		if not hitboxes_visible:
			_clear_viz()


func _process(_delta: float) -> void:
	if overlay_visible:
		_label.text = _build_text()
	if hitboxes_visible:
		_update_viz()


func _build_text() -> String:
	var lines: PackedStringArray = []
	lines.append("FPS %d   (frame %.1f ms)   time_scale %.2f" % [Engine.get_frames_per_second(), 1000.0 / maxf(Engine.get_frames_per_second(), 1.0), Engine.time_scale])
	lines.append("Draw calls %d   objects %d" % [
		int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)),
		int(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME))])
	var director := get_tree().get_first_node_in_group(&"ai_director")
	if director != null:
		lines.append("Attack tokens: %s" % director.call(&"debug_text"))
	var player := get_tree().get_first_node_in_group(&"player") as Node3D
	var providers := get_tree().get_nodes_in_group(&"debug_state")
	var entries: Array = []
	for n in providers:
		if not (n is Node3D) or not n.is_inside_tree():
			continue
		var d := 0.0
		if player != null:
			d = (n as Node3D).global_position.distance_to(player.global_position)
		if d > 30.0:
			continue
		entries.append([d, String(n.call(&"get_debug_state"))])
	entries.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for i in mini(entries.size(), 14):
		lines.append(entries[i][1])
	lines.append("[F3] overlay  [F4] hitboxes")
	return "\n".join(lines)


func _update_viz() -> void:
	var areas: Array[Node] = []
	areas.append_array(get_tree().get_nodes_in_group(&"hitboxes"))
	areas.append_array(get_tree().get_nodes_in_group(&"hurtboxes"))
	for key: Variant in _viz.keys():
		if not is_instance_valid(key):
			var stale: Variant = _viz[key]
			if is_instance_valid(stale):
				(stale as Node).queue_free()
			_viz.erase(key)
	for a in areas:
		var area := a as Area3D
		if area == null or not area.is_inside_tree():
			continue
		var shape_node: CollisionShape3D = null
		for c in area.get_children():
			if c is CollisionShape3D:
				shape_node = c
				break
		if shape_node == null or shape_node.shape == null:
			continue
		var mi: MeshInstance3D = _viz.get(area)
		if mi == null or not is_instance_valid(mi):
			mi = MeshInstance3D.new()
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			shape_node.add_child(mi)
			_viz[area] = mi
		mi.mesh = _mesh_for(shape_node.shape, mi.mesh)
		if area is HitboxComponent:
			mi.material_override = _mat_hit_on if (area as HitboxComponent).active else _mat_hit_off
		elif area is HurtboxComponent:
			var hb := area as HurtboxComponent
			mi.material_override = _mat_hurt_inv if (hb.invulnerable or not hb.monitorable) else _mat_hurt
		else:
			mi.material_override = _mat_hit_off


func _mesh_for(shape: Shape3D, existing: Mesh) -> Mesh:
	if shape is BoxShape3D:
		var bm := existing as BoxMesh
		if bm == null:
			bm = BoxMesh.new()
		bm.size = (shape as BoxShape3D).size
		return bm
	if shape is SphereShape3D:
		var sm := existing as SphereMesh
		if sm == null:
			sm = SphereMesh.new()
		var r := (shape as SphereShape3D).radius
		sm.radius = r
		sm.height = r * 2.0
		return sm
	if shape is CapsuleShape3D:
		var cm := existing as CapsuleMesh
		if cm == null:
			cm = CapsuleMesh.new()
		cm.radius = (shape as CapsuleShape3D).radius
		cm.height = (shape as CapsuleShape3D).height
		return cm
	if shape is CylinderShape3D:
		var cy := existing as CylinderMesh
		if cy == null:
			cy = CylinderMesh.new()
		cy.top_radius = (shape as CylinderShape3D).radius
		cy.bottom_radius = (shape as CylinderShape3D).radius
		cy.height = (shape as CylinderShape3D).height
		return cy
	return existing


func _clear_viz() -> void:
	for key: Variant in _viz:
		var mi: Variant = _viz[key]
		if is_instance_valid(mi):
			(mi as Node).queue_free()
	_viz.clear()
