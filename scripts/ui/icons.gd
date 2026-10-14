class_name DuatIcon
extends Control
## Vector icons drawn with _draw (no texture assets needed): ankh, sun disc, ka arms,
## heart, feather, scales.

enum Kind { ANKH, SUN, KA, HEART, FEATHER, EYE }

@export var kind: Kind = Kind.ANKH
@export var color: Color = UIStyle.GOLD
## 0..1 fill (sun charge progress, empty ankh ...).
@export var fill: float = 1.0
@export var outline: Color = Color(0, 0, 0, 0.7)


func _init(p_kind: Kind = Kind.ANKH, p_size: float = 32.0) -> void:
	kind = p_kind
	custom_minimum_size = Vector2(p_size, p_size)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_fill(v: float) -> void:
	if not is_equal_approx(v, fill):
		fill = v
		queue_redraw()


func _draw() -> void:
	var s := size
	var c := s * 0.5
	var dim := Color(color.r * 0.3, color.g * 0.3, color.b * 0.3, 0.6)
	var col := color if fill >= 0.999 else dim
	match kind:
		Kind.ANKH:
			var w := s.x * 0.14
			draw_arc(Vector2(c.x, s.y * 0.28), s.x * 0.2, 0.0, TAU, 24, outline, w + 3.0)
			draw_arc(Vector2(c.x, s.y * 0.28), s.x * 0.2, 0.0, TAU, 24, col, w)
			draw_rect(Rect2(c.x - w * 0.5 - 1.5, s.y * 0.46, w + 3.0, s.y * 0.52), outline)
			draw_rect(Rect2(s.x * 0.16 - 1.5, s.y * 0.48 - 1.5, s.x * 0.68 + 3.0, w + 3.0), outline)
			draw_rect(Rect2(c.x - w * 0.5, s.y * 0.46, w, s.y * 0.5), col)
			draw_rect(Rect2(s.x * 0.16, s.y * 0.48, s.x * 0.68, w), col)
		Kind.SUN:
			var r := s.x * 0.3
			draw_circle(c, r + 2.0, outline)
			draw_circle(c, r, dim)
			if fill > 0.0:
				if fill >= 0.999:
					draw_circle(c, r, color)
					for i in 8:
						var a := TAU * float(i) / 8.0
						draw_line(c + Vector2(cos(a), sin(a)) * (r + 3.0), c + Vector2(cos(a), sin(a)) * (r + 7.0), color, 2.0)
				else:
					draw_arc(c, r * 0.5, -PI * 0.5, -PI * 0.5 + TAU * fill, 24, color, r)
		Kind.KA:
			# Two raised arms joined at the bottom (the ka hieroglyph).
			var pts_l := PackedVector2Array([Vector2(s.x * 0.2, s.y * 0.1), Vector2(s.x * 0.2, s.y * 0.75), Vector2(s.x * 0.5, s.y * 0.75)])
			var pts_r := PackedVector2Array([Vector2(s.x * 0.8, s.y * 0.1), Vector2(s.x * 0.8, s.y * 0.75), Vector2(s.x * 0.5, s.y * 0.75), Vector2(s.x * 0.5, s.y * 0.95)])
			draw_polyline(pts_l, outline, s.x * 0.16 + 3.0)
			draw_polyline(pts_r, outline, s.x * 0.16 + 3.0)
			draw_polyline(pts_l, col, s.x * 0.16)
			draw_polyline(pts_r, col, s.x * 0.16)
		Kind.HEART:
			var pts := PackedVector2Array()
			for i in 32:
				var t := TAU * float(i) / 32.0
				var x := 16.0 * pow(sin(t), 3.0)
				var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
				pts.append(c + Vector2(x, y) * s.x / 40.0)
			draw_colored_polygon(pts, col)
			pts.append(pts[0])
			draw_polyline(pts, outline, 2.0)
		Kind.FEATHER:
			draw_line(Vector2(c.x, s.y * 0.95), Vector2(c.x, s.y * 0.05), outline, 3.0)
			var pts := PackedVector2Array([Vector2(c.x, s.y * 0.05), Vector2(s.x * 0.78, s.y * 0.3), Vector2(s.x * 0.7, s.y * 0.75), Vector2(c.x, s.y * 0.85), Vector2(s.x * 0.3, s.y * 0.75), Vector2(s.x * 0.22, s.y * 0.3)])
			draw_colored_polygon(pts, col)
			draw_line(Vector2(c.x, s.y * 0.95), Vector2(c.x, s.y * 0.1), Color(0.5, 0.45, 0.3), 1.5)
		Kind.EYE:
			draw_arc(c, s.x * 0.38, PI * 1.1, PI * 1.9, 16, col, 3.0)
			draw_arc(c + Vector2(0, -s.y * 0.2), s.x * 0.38, PI * 0.1, PI * 0.9, 16, col, 3.0)
			draw_circle(c, s.x * 0.12, col)
			draw_line(c + Vector2(-s.x * 0.08, s.y * 0.12), c + Vector2(-s.x * 0.2, s.y * 0.42), col, 3.0)
