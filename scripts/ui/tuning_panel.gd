class_name TuningPanel
extends PanelContainer
## F6: live editor for the active FeelPreset. Every exported property of the preset gets a
## row (number field or checkbox) under its inspector group; edits apply immediately
## (GameState.feel_changed). Buttons switch preset, reload it from disk, save it back to
## its .tres and toggle the FeelProbe console log.

var _rows: VBoxContainer
var _title: Label
var _log_toggle: CheckBox
var _building: bool = false


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.05, 0.08, 0.88)
	sb.border_color = Color(0.85, 0.7, 0.35, 0.6)
	sb.set_border_width_all(1)
	sb.set_content_margin_all(10)
	add_theme_stylebox_override(&"panel", sb)
	custom_minimum_size = Vector2(430, 0)
	var v := VBoxContainer.new()
	add_child(v)
	_title = Label.new()
	_title.add_theme_font_size_override(&"font_size", 17)
	_title.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.5))
	v.add_child(_title)
	var hint := Label.new()
	hint.text = "F6 close · F7 next preset · values apply live (Save writes the .tres)"
	hint.add_theme_font_size_override(&"font_size", 12)
	hint.add_theme_color_override(&"font_color", Color(0.7, 0.75, 0.8))
	v.add_child(hint)
	var presets := HBoxContainer.new()
	v.add_child(presets)
	for p: FeelPreset in GameState.feel_presets:
		var b := Button.new()
		b.text = p.display_name
		b.focus_mode = Control.FOCUS_NONE
		var pid := p.id
		b.pressed.connect(func() -> void: GameState.set_feel_preset(pid))
		presets.add_child(b)
	var tools := HBoxContainer.new()
	v.add_child(tools)
	var reload := Button.new()
	reload.text = "Reload"
	reload.focus_mode = Control.FOCUS_NONE
	reload.pressed.connect(func() -> void: GameState.reload_feel_preset())
	tools.add_child(reload)
	var save := Button.new()
	save.text = "Save .tres"
	save.focus_mode = Control.FOCUS_NONE
	save.pressed.connect(_save)
	tools.add_child(save)
	_log_toggle = CheckBox.new()
	_log_toggle.text = "[feel] log"
	_log_toggle.focus_mode = Control.FOCUS_NONE
	_log_toggle.button_pressed = FeelProbe.log_enabled
	_log_toggle.toggled.connect(func(on: bool) -> void: FeelProbe.log_enabled = on)
	tools.add_child(_log_toggle)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(410, 560)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_rows = VBoxContainer.new()
	_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_rows)
	GameState.feel_changed.connect(_on_feel_changed)
	_rebuild()


func _on_feel_changed(_p: FeelPreset) -> void:
	if not _building:
		_rebuild()


func _rebuild() -> void:
	_building = true
	var p := GameState.feel
	_title.text = "FEEL TUNING — %s" % p.display_name
	for c in _rows.get_children():
		c.queue_free()
	for prop: Dictionary in p.get_property_list():
		var usage := int(prop["usage"])
		var pname := String(prop["name"])
		if usage & PROPERTY_USAGE_GROUP:
			var g := Label.new()
			g.text = pname.to_upper()
			g.add_theme_font_size_override(&"font_size", 13)
			g.add_theme_color_override(&"font_color", Color(0.95, 0.75, 0.4))
			_rows.add_child(g)
			continue
		if not (usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or not (usage & PROPERTY_USAGE_EDITOR):
			continue
		var t := int(prop["type"])
		if t != TYPE_FLOAT and t != TYPE_BOOL:
			continue
		_rows.add_child(_row(p, pname, t))
	_building = false


func _row(p: FeelPreset, pname: String, t: int) -> Control:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = pname.replace("_", " ")
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.add_theme_font_size_override(&"font_size", 13)
	h.add_child(l)
	if t == TYPE_BOOL:
		var cb := CheckBox.new()
		cb.button_pressed = bool(p.get(pname))
		cb.focus_mode = Control.FOCUS_NONE
		cb.toggled.connect(func(on: bool) -> void: _apply_value(pname, on))
		h.add_child(cb)
	else:
		var sp := SpinBox.new()
		var v := float(p.get(pname))
		sp.min_value = -1.0
		sp.max_value = 2000.0
		sp.step = 0.001 if absf(v) < 2.0 else (0.01 if absf(v) < 20.0 else 0.5)
		sp.allow_greater = true
		sp.value = v
		sp.custom_minimum_size = Vector2(110, 0)
		sp.value_changed.connect(func(nv: float) -> void: _apply_value(pname, nv))
		h.add_child(sp)
	return h


func _apply_value(pname: String, value: Variant) -> void:
	_building = true
	GameState.feel.set(pname, value)
	GameState.feel_changed.emit(GameState.feel)
	_building = false


func _save() -> void:
	var p := GameState.feel
	var err := ResourceSaver.save(p, p.resource_path)
	DebugOverlay.toast("Saved %s (%s)" % [p.resource_path, error_string(err)])
