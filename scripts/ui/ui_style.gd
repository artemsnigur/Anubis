class_name UIStyle
extends RefCounted
## Shared UI look: gold on dark lapis, papyrus frames, serif headings.

const LAPIS := Color(0.05, 0.08, 0.2, 0.92)
const LAPIS_LIGHT := Color(0.1, 0.16, 0.38, 0.95)
const GOLD := Color(0.96, 0.77, 0.32)
const GOLD_DIM := Color(0.62, 0.48, 0.2)
const PAPYRUS := Color(0.86, 0.78, 0.58)
const PAPYRUS_DARK := Color(0.66, 0.56, 0.36)
const INK := Color(0.2, 0.12, 0.05)
const TURQUOISE := Color(0.25, 0.8, 0.75)
const BLOOD := Color(0.75, 0.16, 0.1)

static var _theme: Theme
static var _heading_font: Font
static var _body_font: Font


static func heading_font() -> Font:
	if _heading_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Cinzel", "Trajan Pro", "Optima", "Palatino", "Georgia", "Times New Roman", "serif"])
		f.font_weight = 700
		_heading_font = f
	return _heading_font


static func body_font() -> Font:
	if _body_font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Palatino", "Georgia", "Book Antiqua", "Times New Roman", "serif"])
		_body_font = f
	return _body_font


static func lapis_box(border: Color = GOLD, width: int = 2, radius: int = 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = LAPIS
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(12)
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 6
	return sb


static func papyrus_box() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPYRUS
	sb.border_color = PAPYRUS_DARK
	sb.set_border_width_all(6)
	sb.border_width_top = 10
	sb.border_width_bottom = 10
	sb.set_corner_radius_all(2)
	sb.set_content_margin_all(28)
	sb.shadow_color = Color(0, 0, 0, 0.6)
	sb.shadow_size = 14
	return sb


static func theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.default_font = body_font()
	t.default_font_size = 24
	# Buttons: lapis with gold frame, brighter on focus/hover (gamepad friendly).
	var normal := lapis_box(GOLD_DIM, 2, 3)
	normal.set_content_margin_all(10)
	normal.content_margin_left = 22
	normal.content_margin_right = 22
	var hover := normal.duplicate() as StyleBoxFlat
	hover.bg_color = LAPIS_LIGHT
	hover.border_color = GOLD
	var focus := hover.duplicate() as StyleBoxFlat
	focus.set_border_width_all(3)
	focus.draw_center = false
	var pressed := hover.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.16, 0.12, 0.05, 0.95)
	var disabled := normal.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.08, 0.08, 0.1, 0.7)
	disabled.border_color = Color(0.3, 0.3, 0.3)
	t.set_stylebox(&"normal", &"Button", normal)
	t.set_stylebox(&"hover", &"Button", hover)
	t.set_stylebox(&"focus", &"Button", focus)
	t.set_stylebox(&"pressed", &"Button", pressed)
	t.set_stylebox(&"disabled", &"Button", disabled)
	t.set_color(&"font_color", &"Button", PAPYRUS)
	t.set_color(&"font_hover_color", &"Button", GOLD)
	t.set_color(&"font_focus_color", &"Button", GOLD)
	t.set_color(&"font_pressed_color", &"Button", GOLD)
	t.set_color(&"font_disabled_color", &"Button", Color(0.5, 0.5, 0.5))
	t.set_font(&"font", &"Button", heading_font())
	t.set_font_size(&"font_size", &"Button", 24)
	t.set_color(&"font_color", &"Label", PAPYRUS)
	t.set_color(&"font_outline_color", &"Label", Color(0, 0, 0, 0.8))
	t.set_constant(&"outline_size", &"Label", 4)
	t.set_stylebox(&"panel", &"PanelContainer", lapis_box())
	t.set_stylebox(&"panel", &"Panel", lapis_box())
	# Sliders.
	var track := StyleBoxFlat.new()
	track.bg_color = Color(0.1, 0.1, 0.16)
	track.border_color = GOLD_DIM
	track.set_border_width_all(1)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = GOLD_DIM
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	t.set_stylebox(&"slider", &"HSlider", track)
	t.set_stylebox(&"grabber_area", &"HSlider", fill)
	t.set_stylebox(&"grabber_area_highlight", &"HSlider", fill)
	t.set_color(&"font_color", &"CheckButton", PAPYRUS)
	t.set_color(&"font_focus_color", &"CheckButton", GOLD)
	t.set_color(&"font_hover_color", &"CheckButton", GOLD)
	_theme = t
	return t


static func label(text: String, size: int = 24, color: Color = PAPYRUS, heading: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	if heading:
		l.add_theme_font_override(&"font", heading_font())
	return l


static func button(text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(callback)
	b.pressed.connect(func() -> void: AudioManager.play_event(&"ui_click"))
	b.focus_entered.connect(func() -> void: AudioManager.play_event(&"ui_move"))
	b.mouse_entered.connect(func() -> void: b.grab_focus())
	return b


## Prompt glyph for an action given the active device.
static func action_glyph(action: StringName, gamepad: bool) -> String:
	if gamepad:
		match action:
			&"interact": return "Ⓐ"
			&"heal": return "Ⓧ"
			&"dodge": return "Ⓑ"
			&"attack_light": return "RB"
			&"attack_heavy": return "RT"
			&"ranged": return "LB"
			&"lock_on": return "R3"
	match action:
		&"interact": return "E"
		&"heal": return "R"
		&"dodge": return "Space"
		&"attack_light": return "LMB"
		&"attack_heavy": return "RMB"
		&"ranged": return "Q"
		&"lock_on": return "Tab"
	return String(action)
