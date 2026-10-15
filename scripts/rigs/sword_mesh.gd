class_name SwordMesh
extends RefCounted
## Procedural straight sword (bronze blade, gold guard and pommel, wrapped grip).
## Built in socket space like the old khopesh: the hand holds the grip at the origin,
## the pommel is toward +Y, the blade runs along -Y to the point at -BLADE_END.
## The blade is wide along Z (edges face +Z / -Z) and thin along X, with a central ridge.

const GRIP_TOP := 0.09
const GUARD_Y := -0.1
const BLADE_START := -0.12
const BLADE_END := 1.0
const HALF_WIDTH := 0.032
const HALF_THICK := 0.007


## Blade only (diamond cross-section, tapering to a point).
static func build_blade() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	var n := 10
	for i in n + 1:
		var u := float(i) / float(n)
		var y := lerpf(BLADE_START, -BLADE_END, u)
		# Slight leaf shape, then a long taper to the point.
		var w := HALF_WIDTH * (1.0 + 0.12 * sin(u * PI * 0.8)) * (1.0 - pow(u, 3.2))
		if i == n:
			w = 0.0
		var t := HALF_THICK * (1.0 - 0.6 * u)
		# Diamond: edge +Z, ridge +X, edge -Z, ridge -X.
		rings.append([Vector3(0, y, w), Vector3(t, y, 0), Vector3(0, y, -w), Vector3(-t, y, 0)])
	for i in n:
		var a: Array = rings[i]
		var b: Array = rings[i + 1]
		for k in 4:
			var k2 := (k + 1) % 4
			_quad(st, a[k], b[k], b[k2], a[k2])
	# Cap at the guard end.
	var c: Array = rings[0]
	st.add_vertex(c[0])
	st.add_vertex(c[1])
	st.add_vertex(c[2])
	st.add_vertex(c[0])
	st.add_vertex(c[2])
	st.add_vertex(c[3])
	st.generate_normals()
	return st.commit()


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	st.add_vertex(a)
	st.add_vertex(b)
	st.add_vertex(c)
	st.add_vertex(a)
	st.add_vertex(c)
	st.add_vertex(d)


## Builds the whole sword under `socket`; returns {"blade": MeshInstance3D, "tip": Node3D, "base": Node3D}.
static func attach(socket: Node3D, blade_mat: Material, gold: Material, grip_mat: Material) -> Dictionary:
	var blade := MeshInstance3D.new()
	blade.name = "Blade"
	blade.mesh = PlaceholderRig.cached_mesh("sword_blade", build_blade)
	blade.material_override = blade_mat
	socket.add_child(blade)
	var grip := MeshInstance3D.new()
	grip.mesh = PlaceholderRig.cylinder(0.019, 0.021, GRIP_TOP - GUARD_Y, 8)
	grip.material_override = grip_mat
	grip.position = Vector3(0, (GRIP_TOP + GUARD_Y) * 0.5, 0)
	socket.add_child(grip)
	var guard := MeshInstance3D.new()
	guard.mesh = PlaceholderRig.box(Vector3(0.03, 0.028, 0.19))
	guard.material_override = gold
	guard.position = Vector3(0, GUARD_Y, 0)
	socket.add_child(guard)
	var pommel := MeshInstance3D.new()
	pommel.mesh = PlaceholderRig.sphere(0.03, 0.05, 8)
	pommel.material_override = gold
	pommel.position = Vector3(0, GRIP_TOP + 0.02, 0)
	socket.add_child(pommel)
	var base := Node3D.new()
	base.name = "TrailBase"
	# The trail ribbon covers the outer part of the blade only.
	base.position = Vector3(0, -0.5, 0)
	socket.add_child(base)
	var tip := Node3D.new()
	tip.name = "TrailTip"
	tip.position = Vector3(0, -BLADE_END + 0.02, 0)
	socket.add_child(tip)
	return {"blade": blade, "tip": tip, "base": base}
