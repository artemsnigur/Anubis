class_name Fader
extends CanvasLayer
## Full-screen fades and flashes.

var _rect: ColorRect


func _ready() -> void:
	layer = 60
	process_mode = Node.PROCESS_MODE_ALWAYS
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.color = Color(0, 0, 0, 0)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)


func fade_out(duration: float = 0.6, color: Color = Color.BLACK) -> void:
	_rect.color = Color(color.r, color.g, color.b, _rect.color.a)
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_rect, "color:a", 1.0, duration)
	await tw.finished


func fade_in(duration: float = 0.8) -> void:
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_rect, "color:a", 0.0, duration)
	await tw.finished


func flash(color: Color = Color.WHITE, duration: float = 0.5, peak: float = 0.9) -> void:
	_rect.color = Color(color.r, color.g, color.b, peak)
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(_rect, "color:a", 0.0, duration).set_ease(Tween.EASE_IN)


func set_black() -> void:
	_rect.color = Color(0, 0, 0, 1)
