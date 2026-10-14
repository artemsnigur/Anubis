extends SceneTree
## Dev tool: generates procedural textures into res://assets/textures/.
##   noise_stone.png  - seamless fractal noise for triplanar materials
##   noise_fine.png   - seamless high-frequency noise
##   hieroglyphs.png  - columns of procedurally drawn glyphs (white on black)
## Run: godot --headless --script res://tools/generate_textures.gd

const OUT := "res://assets/textures/"
var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = 7741
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	_save_noise("noise_stone.png", 512, 0.008, 5, FastNoiseLite.TYPE_SIMPLEX_SMOOTH, 101)
	_save_noise("noise_fine.png", 256, 0.04, 3, FastNoiseLite.TYPE_CELLULAR, 202)
	_save_glyphs("hieroglyphs.png", 1024)
	print("generate_textures: done")
	quit(0)


func _save_noise(file: String, size: int, freq: float, octaves: int, type: FastNoiseLite.NoiseType, seed_value: int) -> void:
	var n := FastNoiseLite.new()
	n.noise_type = type
	n.frequency = freq
	n.fractal_octaves = octaves
	n.seed = seed_value
	var img := n.get_seamless_image(size, size, false, false, 0.15, true)
	img.convert(Image.FORMAT_L8)
	img.save_png(OUT + file)


# --- hieroglyphs ---------------------------------------------------------------

var _img: Image


func _save_glyphs(file: String, size: int) -> void:
	_img = Image.create(size, size, false, Image.FORMAT_L8)
	_img.fill(Color.BLACK)
	var col_w := 128
	var cell := 112
	var cols := size / col_w
	for c in cols:
		var x0 := c * col_w
		# column separator lines
		_rect(x0 + 2, 0, 4, size, 0.85)
		var y := 10
		while y + cell < size:
			var cx := x0 + col_w / 2 + 3
			var cy := y + cell / 2
			_glyph(rng.randi_range(0, 13), cx, cy, cell * 0.36)
			y += cell + rng.randi_range(0, 10)
	_img.save_png(OUT + file)


func _glyph(kind: int, cx: int, cy: int, s: float) -> void:
	var si := int(s)
	match kind:
		0: # ankh
			_ring(cx, cy - si / 2, si / 3, si / 5, 1.0)
			_rect(cx - si / 10, cy - si / 4, si / 5, si + si / 4, 1.0)
			_rect(cx - si / 2, cy - si / 6, si, si / 6, 1.0)
		1: # eye
			_ellipse_ring(cx, cy - si / 6, si * 0.7, si * 0.32, 5.0)
			_disc(cx, cy - si / 6, si / 5, 1.0)
			_line(cx - si / 4, cy + si / 6, cx - si / 2, cy + si * 0.7, 5.0)
			_line(cx + si / 6, cy + si / 6, cx + si / 2, cy + si / 2, 5.0)
		2: # water (zigzag lines)
			for k in 3:
				var yy := cy - si / 2 + k * si / 2
				for i in 6:
					var xa := cx - si + i * si / 3
					_line(xa, yy, xa + si / 6, yy - si / 6, 4.0)
					_line(xa + si / 6, yy - si / 6, xa + si / 3, yy, 4.0)
		3: # sun disc with uraeus
			_disc(cx, cy, si / 2, 1.0)
			_ring(cx, cy, si * 0.75, 4, 1.0)
		4: # bird (simplified)
			_ellipse(cx, cy, si * 0.55, si * 0.3, 1.0)
			_disc(cx + si / 2, cy - si / 3, si / 5, 1.0)
			_line(cx + si / 2, cy - si / 3, cx + si, cy - si / 4, 5.0)
			_line(cx - si / 6, cy + si / 4, cx - si / 6, cy + si * 0.8, 4.0)
			_line(cx + si / 6, cy + si / 4, cx + si / 6, cy + si * 0.8, 4.0)
			_line(cx - si / 2, cy, cx - si, cy + si / 3, 6.0)
		5: # reed leaf
			_ellipse(cx, cy, si * 0.18, si * 0.85, 1.0)
			_line(cx, cy - si, cx + si / 4, cy - si * 1.1, 4.0)
		6: # cartouche
			_ellipse_ring(cx, cy, si * 0.55, si * 1.0, 5.0)
			_rect(cx - si / 2, cy + si, si, 6, 1.0)
			_disc(cx, cy - si / 3, si / 6, 1.0)
			_rect(cx - si / 4, cy + si / 6, si / 2, 5, 1.0)
		7: # djed pillar
			_rect(cx - si / 6, cy - si, si / 3, si * 2, 1.0)
			for k in 4:
				_rect(cx - si / 2, cy - si + k * si / 6, si, si / 12, 1.0)
		8: # snake
			for i in 12:
				var t := float(i) / 11.0
				_disc(cx - s + t * s * 2.0, cy + sin(t * 9.0) * s * 0.3, maxf(3.0, s / 8.0), 1.0)
		9: # feather of Ma'at
			_ellipse(cx, cy, si * 0.25, si, 1.0)
			_line(cx, cy - si, cx + si / 3, cy - si - si / 4, 5.0)
			_rect(cx - 2, cy - si, 4, si * 2, 0.0)
		10: # seated figure
			_disc(cx, cy - si * 0.8, si / 5, 1.0)
			_rect(cx - si / 5, cy - si * 0.6, si / 2, si * 0.8, 1.0)
			_rect(cx - si / 5, cy + si / 6, si, si / 4, 1.0)
			_rect(cx + si / 2, cy + si / 6, si / 5, si * 0.7, 1.0)
		11: # bread loaf / half circle
			_half_disc(cx, cy + si / 4, si * 0.7, 1.0)
		12: # basket
			_half_disc(cx, cy - si / 4, si * 0.8, 1.0)
			_half_disc(cx, cy - si / 4, si * 0.55, 0.0)
		13: # scarab
			_ellipse(cx, cy, si * 0.4, si * 0.6, 1.0)
			_disc(cx, cy - si * 0.7, si / 5, 1.0)
			_line(cx - si / 3, cy, cx - si, cy - si / 3, 4.0)
			_line(cx + si / 3, cy, cx + si, cy - si / 3, 4.0)
			_line(cx - si / 3, cy + si / 3, cx - si, cy + si * 0.6, 4.0)
			_line(cx + si / 3, cy + si / 3, cx + si, cy + si * 0.6, 4.0)


func _put(x: int, y: int, v: float) -> void:
	if x >= 0 and y >= 0 and x < _img.get_width() and y < _img.get_height():
		_img.set_pixel(x, y, Color(v, v, v))


func _rect(xf: float, yf: float, wf: float, hf: float, v: float) -> void:
	var x := int(xf)
	var y := int(yf)
	for yy in range(y, y + int(hf)):
		for xx in range(x, x + int(wf)):
			_put(xx, yy, v)


func _disc(cxf: float, cyf: float, rf: float, v: float) -> void:
	var cx := int(cxf)
	var cy := int(cyf)
	var r := int(rf)
	for yy in range(cy - r, cy + r + 1):
		for xx in range(cx - r, cx + r + 1):
			if (xx - cx) * (xx - cx) + (yy - cy) * (yy - cy) <= r * r:
				_put(xx, yy, v)


func _half_disc(cxf: float, cyf: float, rf: float, v: float) -> void:
	var cx := int(cxf)
	var cy := int(cyf)
	var ri := int(rf)
	for yy in range(cy - ri, cy + 1):
		for xx in range(cx - ri, cx + ri + 1):
			if (xx - cx) * (xx - cx) + (yy - cy) * (yy - cy) <= ri * ri:
				_put(xx, yy, v)


func _ring(cxf: float, cyf: float, rf: float, wf: float, v: float) -> void:
	var cx := int(cxf)
	var cy := int(cyf)
	var r := int(rf)
	var w := int(wf)
	for yy in range(cy - r - w, cy + r + w + 1):
		for xx in range(cx - r - w, cx + r + w + 1):
			var d := sqrt(float((xx - cx) * (xx - cx) + (yy - cy) * (yy - cy)))
			if absf(d - float(r)) <= float(w) * 0.5:
				_put(xx, yy, v)


func _ellipse(cxf: float, cyf: float, rx: float, ry: float, v: float) -> void:
	for yy in range(int(cyf - ry), int(cyf + ry) + 1):
		for xx in range(int(cxf - rx), int(cxf + rx) + 1):
			var dx := (xx - cxf) / rx
			var dy := (yy - cyf) / ry
			if dx * dx + dy * dy <= 1.0:
				_put(xx, yy, v)


func _ellipse_ring(cxf: float, cyf: float, rx: float, ry: float, w: float) -> void:
	for yy in range(int(cyf - ry - w), int(cyf + ry + w) + 1):
		for xx in range(int(cxf - rx - w), int(cxf + rx + w) + 1):
			var dx := (xx - cxf) / rx
			var dy := (yy - cyf) / ry
			var d := sqrt(dx * dx + dy * dy)
			if absf(d - 1.0) * minf(rx, ry) <= w * 0.5:
				_put(xx, yy, 1.0)


func _line(x0: float, y0: float, x1: float, y1: float, w: float) -> void:
	var steps := int(maxf(absf(x1 - x0), absf(y1 - y0)))
	for i in steps + 1:
		var t := float(i) / float(maxi(steps, 1))
		_disc(lerpf(x0, x1, t), lerpf(y0, y1, t), w * 0.5, 1.0)
