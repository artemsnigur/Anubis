extends CanvasLayer
## Debug tools.
##  F3 - overlay with FPS and the current state of every state machine nearby.
##        Includes the FeelProbe section (input latencies, lockouts in 60 Hz frames).
##  F6 - feel tuning panel (live editor of the active FeelPreset).
##  F7 - next feel preset (Grounded -> Snappy -> Old), shown as a toast.
##  F4 - draws hitboxes (red when active) and hurtboxes (green, blue = invulnerable).

var overlay_visible: bool = false
var hitboxes_visible: bool = false
var _label: Label
var _feel: RichTextLabel
var _timeline: WindowTimeline
var _tuning: TuningPanel
var _toast: Label
var _toast_tween: Tween
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
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(box)
	_label = Label.new()
	_label.add_theme_font_size_override(&"font_size", 15)
	_label.add_theme_color_override(&"font_color", Color(0.85, 1.0, 0.85))
	box.add_child(_label)
	_feel = RichTextLabel.new()
	_feel.bbcode_enabled = true
	_feel.fit_content = true
	_feel.scroll_active = false
	_feel.autowrap_mode = TextServer.AUTOWRAP_OFF
	_feel.custom_minimum_size = Vector2(760, 0)
	_feel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_feel.add_theme_font_size_override(&"normal_font_size", 14)
	_feel.add_theme_font_size_override(&"bold_font_size", 14)
	box.add_child(_feel)
	_timeline = WindowTimeline.new()
	box.add_child(_timeline)
	_panel.visible = false
	_toast = Label.new()
	_toast.add_theme_font_size_override(&"font_size", 26)
	_toast.add_theme_color_override(&"font_color", Color(1.0, 0.88, 0.55))
	_toast.add_theme_color_override(&"font_outline_color", Color(0, 0, 0, 0.9))
	_toast.add_theme_constant_override(&"outline_size", 8)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.offset_top = 90
	_toast.offset_left = -400
	_toast.offset_right = 400
	_toast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast.modulate.a = 0.0
	add_child(_toast)
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


## True while the mouse is over a debug panel (its clicks must not reach the game).
func ui_has_mouse() -> bool:
	if _tuning == null or not _tuning.visible:
		return false
	return _tuning.get_global_rect().has_point(_tuning.get_global_mouse_position())


## Short centred message that fades out (preset changes, saves).
func toast(text: String) -> void:
	_toast.text = text
	if _toast_tween != null:
		_toast_tween.kill()
	_toast.modulate.a = 1.0
	_toast_tween = create_tween()
	_toast_tween.tween_interval(1.2)
	_toast_tween.tween_property(_toast, "modulate:a", 0.0, 0.6)


func toggle_tuning() -> void:
	if _tuning == null:
		_tuning = TuningPanel.new()
		_tuning.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		_tuning.position = Vector2(get_viewport().get_visible_rect().size.x - 450, 12)
		add_child(_tuning)
		return
	_tuning.visible = not _tuning.visible


func cycle_preset() -> void:
	var p := GameState.cycle_feel_preset()
	toast("Feel preset: %s" % p.display_name)
	print("[feel] preset -> ", p.display_name)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"debug_overlay"):
		overlay_visible = not overlay_visible
		_panel.visible = overlay_visible
	elif event.is_action_pressed(&"debug_tuning"):
		toggle_tuning()
	elif event.is_action_pressed(&"feel_preset_next"):
		cycle_preset()
	elif event.is_action_pressed(&"debug_hitboxes"):
		hitboxes_visible = not hitboxes_visible
		if not hitboxes_visible:
			_clear_viz()


func _process(_delta: float) -> void:
	if overlay_visible:
		_label.text = _build_text()
		_feel.text = FeelProbe.overlay_text()
		_timeline.queue_redraw()
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
	lines.append("[F3] overlay  [F4] hitboxes  [F6] feel tuning  [F7] feel preset: %s" % GameState.feel.display_name)
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


## Cancel-window timeline of the hero's current action (F3): phase bars (windup gold,
## active red, recovery grey), markers where dodge (blue), attack (gold), movement
## (green) and the combo queue (violet) open, and the current time (white).
class WindowTimeline:
	extends Control

	const COLORS := {"dodge": Color(0.35, 0.65, 1.0), "attack": Color(1.0, 0.8, 0.3), "move": Color(0.45, 1.0, 0.5), "queue": Color(0.8, 0.5, 1.0)}

	func _init() -> void:
		custom_minimum_size = Vector2(760, 46)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var player := get_tree().get_first_node_in_group(&"player") as Player
		if player == null or player.fsm.current == null:
			return
		var w: Dictionary = {}
		if player.fsm.current.has_method(&"windows"):
			w = player.fsm.current.call(&"windows")
		var font := get_theme_default_font()
		if w.is_empty():
			draw_string(font, Vector2(0, 14), "windows: %s (free)" % player.fsm.current_name(), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.7, 0.8, 0.75))
			return
		var total := maxf(float(w["total"]), 0.001)
		var x0 := 0.0
		var width := size.x - 10.0
		var y := 18.0
		var t := float(w["t"])
		draw_string(font, Vector2(0, 13), "windows: %s   t %d f / %d f" % [w["name"], roundi(t * 60.0), roundi(total * 60.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.85, 0.95, 0.85))
		for ph: Array in w["phases"]:
			var pw := float(ph[0]) / total * width
			draw_rect(Rect2(x0, y, pw, 10), ph[1] as Color)
			x0 += pw
		var marks: Dictionary = w["marks"]
		var label_x := 0.0
		for k: String in marks:
			var mx := clampf(float(marks[k]) / total, 0.0, 1.0) * width
			var col: Color = COLORS.get(k, Color.WHITE)
			draw_line(Vector2(mx, y - 3), Vector2(mx, y + 14), col, 2.0)
			draw_string(font, Vector2(label_x, y + 26), "%s %df" % [k, roundi(float(marks[k]) * 60.0)], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
			label_x += 96.0
		var cx := clampf(t / total, 0.0, 1.0) * width
		draw_line(Vector2(cx, y - 5), Vector2(cx, y + 15), Color.WHITE, 2.0)
