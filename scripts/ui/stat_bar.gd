class_name StatBar
extends Control
## Bar with gold frame, dark well, trailing "lag" segment and fill colour.

@export var fill_color: Color = Color(0.78, 0.16, 0.1)
@export var lag_color: Color = Color(1.0, 0.85, 0.6, 0.85)
@export var back_color: Color = Color(0.04, 0.04, 0.07, 0.85)
@export var frame_color: Color = UIStyle.GOLD
@export var lag_speed: float = 0.6

var value: float = 1.0
var max_value: float = 1.0
var _lag: float = 1.0
var _lag_delay: float = 0.0
var _flash: float = 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(current: float, maximum: float) -> void:
	var r_old := value / maxf(max_value, 0.001)
	value = current
	max_value = maximum
	var r := value / maxf(max_value, 0.001)
	if r < r_old - 0.001:
		_lag_delay = 0.45
		_flash = 1.0
	elif r > _lag:
		_lag = r
	queue_redraw()


func ratio() -> float:
	return clampf(value / maxf(max_value, 0.001), 0.0, 1.0)


func _process(delta: float) -> void:
	var r := ratio()
	if _lag_delay > 0.0:
		_lag_delay -= delta
	elif _lag > r:
		_lag = maxf(r, _lag - lag_speed * delta)
		queue_redraw()
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - delta * 4.0)
		queue_redraw()


func _draw() -> void:
	var s := size
	draw_rect(Rect2(Vector2(-3, -3), s + Vector2(6, 6)), Color(0, 0, 0, 0.6))
	draw_rect(Rect2(Vector2.ZERO, s), back_color)
	var r := ratio()
	if _lag > r:
		draw_rect(Rect2(Vector2(s.x * r, 0), Vector2(s.x * (_lag - r), s.y)), lag_color)
	var fc := fill_color.lerp(Color.WHITE, _flash * 0.5)
	draw_rect(Rect2(Vector2.ZERO, Vector2(s.x * r, s.y)), fc)
	draw_rect(Rect2(Vector2(0, 0), Vector2(s.x * r, s.y * 0.35)), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(Vector2.ZERO, s), frame_color, false, 2.0)
	# Small gold end caps (papyrus-scroll feel).
	draw_rect(Rect2(Vector2(-6, -4), Vector2(4, s.y + 8)), frame_color)
	draw_rect(Rect2(Vector2(s.x + 2, -4), Vector2(4, s.y + 8)), frame_color)
