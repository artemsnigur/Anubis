class_name SettingsPanel
extends PanelContainer
## Volume sliders, camera-shake strength, fullscreen toggle. Saved immediately.

signal closed

var _first: Control


func _ready() -> void:
	add_theme_stylebox_override(&"panel", UIStyle.papyrus_box())
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	add_child(box)
	var title := UIStyle.label("SETTINGS", 40, UIStyle.INK, true)
	title.add_theme_constant_override(&"outline_size", 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	_first = _slider_row(box, "Master volume", &"master_volume", Settings.master_volume, 1.0)
	_slider_row(box, "Music volume", &"music_volume", Settings.music_volume, 1.0)
	_slider_row(box, "Effects volume", &"sfx_volume", Settings.sfx_volume, 1.0)
	_slider_row(box, "Camera shake", &"shake_strength", Settings.shake_strength, 1.5)
	var fs := CheckButton.new()
	fs.text = "Fullscreen"
	fs.button_pressed = Settings.fullscreen
	fs.add_theme_color_override(&"font_color", UIStyle.INK)
	fs.add_theme_font_override(&"font", UIStyle.heading_font())
	fs.toggled.connect(func(v: bool) -> void: Settings.set_value(&"fullscreen", v))
	box.add_child(fs)
	var back := UIStyle.button("Back", func() -> void: closed.emit())
	box.add_child(back)


func _slider_row(parent: Container, text: String, key: StringName, value: float, max_value: float) -> HSlider:
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 18)
	parent.add_child(row)
	var l := UIStyle.label(text, 24, UIStyle.INK)
	l.add_theme_constant_override(&"outline_size", 0)
	l.custom_minimum_size = Vector2(230, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = max_value
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(320, 30)
	s.focus_mode = Control.FOCUS_ALL
	s.value_changed.connect(func(v: float) -> void:
		Settings.set_value(key, v)
		AudioManager.play_event(&"ui_move"))
	row.add_child(s)
	return s


func focus_first() -> void:
	if _first != null:
		_first.grab_focus()
