class_name DeathScreen
extends CanvasLayer
## "YOUR HEART HAS BEEN WEIGHED" - the heart (Ka) is left where the hero fell.

signal finished

var _root: Control
var _title: Label
var _sub: Label
var _hint: Label
var _heart: DuatIcon
var _feather: DuatIcon
var _waiting: bool = false


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIStyle.theme()
	_root.visible = false
	add_child(_root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.06, 0.0, 0.0, 0.82)
	_root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 18)
	center.add_child(box)
	var scales := HBoxContainer.new()
	scales.alignment = BoxContainer.ALIGNMENT_CENTER
	scales.add_theme_constant_override(&"separation", 120)
	box.add_child(scales)
	_heart = DuatIcon.new(DuatIcon.Kind.HEART, 72.0)
	_heart.color = Color(0.8, 0.12, 0.1)
	scales.add_child(_heart)
	_feather = DuatIcon.new(DuatIcon.Kind.FEATHER, 72.0)
	_feather.color = Color(0.95, 0.93, 0.85)
	scales.add_child(_feather)
	_title = UIStyle.label("YOUR HEART HAS BEEN WEIGHED", 64, Color(0.86, 0.2, 0.12), true)
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_constant_override(&"outline_size", 10)
	box.add_child(_title)
	_sub = UIStyle.label("", 26, UIStyle.PAPYRUS)
	_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_sub)
	_hint = UIStyle.label("", 20, UIStyle.GOLD_DIM)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_hint)


func show_death(ka_lost: int, heart_lost: bool) -> void:
	_root.visible = true
	_root.modulate.a = 0.0
	var lines: PackedStringArray = []
	if ka_lost > 0:
		lines.append("%d Ka remain in your heart where you fell." % ka_lost)
		lines.append("Reclaim it before you fall again.")
	else:
		lines.append("You carried no Ka. The Devourer finds nothing to eat.")
	if heart_lost:
		lines.append("The heart you left before has been devoured.")
	_sub.text = "\n".join(lines)
	_hint.text = ""
	_title.scale = Vector2.ONE
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_root, "modulate:a", 1.0, 1.4)
	# The scales tip: the heart sinks, the feather rises.
	tw.parallel().tween_property(_heart, "position:y", 26.0, 1.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_feather, "position:y", -26.0, 1.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		_hint.text = "Press any button to return to the Altar of Osiris"
		_waiting = true)
	tw.tween_interval(4.0)
	tw.tween_callback(_finish)


func _input(event: InputEvent) -> void:
	if not _waiting:
		return
	if (event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton) and event.is_pressed():
		_finish()


func _finish() -> void:
	if not _waiting:
		return
	_waiting = false
	finished.emit()


func hide_screen() -> void:
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_root, "modulate:a", 0.0, 0.6)
	tw.tween_callback(func() -> void: _root.visible = false)
