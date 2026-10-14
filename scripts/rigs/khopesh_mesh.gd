class_name KhopeshMesh
extends RefCounted
## Procedural khopesh (sickle-sword) mesh. Built in socket space: the grip runs along
## -Y from the socket, the hooked blade curves toward -Z (the cutting edge is outside).

const THICKNESS := 0.018


## Returns centerline samples (y, z) of the blade with their half-widths.
static func centerline() -> Array:
	var pts: Array = []
	# Straight section.
	for i in 6:
		var t := float(i) / 5.0
		pts.append([Vector2(0.0, lerpf(-0.12, -0.38, t)), lerpf(0.022, 0.03, t)])
	# Hooked section: arc around a centre in front of the blade.
	var c := Vector2(-0.18, -0.38)
	var r := 0.18
	for i in range(1, 15):
		var a := deg_to_rad(lerpf(0.0, -215.0, float(i) / 14.0))
		var p := c + Vector2(cos(a), sin(a)) * r
		var w := lerpf(0.034, 0.004, pow(float(i) / 14.0, 1.6))
		pts.append([p, w])
	return pts


static func build() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := centerline()
	var outer: Array[Vector3] = []
	var inner: Array[Vector3] = []
	for i in pts.size():
		var p: Vector2 = pts[i][0]
		var w: float = pts[i][1]
		var prev: Vector2 = pts[maxi(i - 1, 0)][0]
		var next: Vector2 = pts[mini(i + 1, pts.size() - 1)][0]
		var tangent := (next - prev).normalized()
		# Normal pointing to the outside of the curve (the cutting edge).
		var n := Vector2(tangent.y, -tangent.x)
		var o := p + n * w * 1.4
		var inn := p - n * w * 0.6
		# x = 2D.x (z axis), y = 2D.y
		outer.append(Vector3(0.0, o.y, o.x))
		inner.append(Vector3(0.0, inn.y, inn.x))
	var half := THICKNESS * 0.5
	for i in range(pts.size() - 1):
		var a0 := outer[i]
		var a1 := outer[i + 1]
		var b0 := inner[i]
		var b1 := inner[i + 1]
		# The cutting edge is thinner (bevel): outer verts sit at x = 0.
		var ox := Vector3(half * 0.15, 0, 0)
		var ix := Vector3(half, 0, 0)
		_quad(st, a0 + ox, a1 + ox, b1 + ix, b0 + ix)
		_quad(st, b0 - ix, b1 - ix, a1 - ox, a0 - ox)
		_quad(st, b0 + ix, b1 + ix, b1 - ix, b0 - ix)
		_quad(st, a1 + ox, a0 + ox, a0 - ox, a1 - ox)
	st.generate_normals()
	return st.commit()


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)
