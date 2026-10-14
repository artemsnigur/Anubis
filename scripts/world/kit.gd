class_name Kit
extends RefCounted
## Modular level kit built from primitives: floors, walls, lotus-capital columns,
## stairs (visual steps + smooth ramp collider), arches, statues, obelisks, torches.
## All solids are StaticBody3D on the "world" layer so navigation can bake from them.

static var _mesh_cache: Dictionary = {}
static var _flame_mat: StandardMaterial3D
static var _ember_proc: ParticleProcessMaterial
static var _ember_mesh: QuadMesh


static func _box_mesh(size: Vector3) -> BoxMesh:
	var k := "b%s" % size
	if not _mesh_cache.has(k):
		var m := BoxMesh.new()
		m.size = size
		_mesh_cache[k] = m
	return _mesh_cache[k]


static func _cyl_mesh(top: float, bottom: float, h: float, sides: int = 16) -> CylinderMesh:
	var k := "c%.3f_%.3f_%.3f_%d" % [top, bottom, h, sides]
	if not _mesh_cache.has(k):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = h
		m.radial_segments = sides
		m.rings = 1
		_mesh_cache[k] = m
	return _mesh_cache[k]


static func mesh(parent: Node3D, m: Mesh, mat: Material, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE, shadows: bool = true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Solid box (collision + mesh). `center` is the box centre.
static func box(parent: Node3D, center: Vector3, size: Vector3, mat: Material, layer: int = CombatTypes.LAYER_WORLD, yaw_deg: float = 0.0) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = layer
	body.collision_mask = 0
	body.position = center
	body.rotation_degrees = Vector3(0, yaw_deg, 0)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	mesh(body, _box_mesh(size), mat, Vector3.ZERO)
	return body


## Floor slab whose top surface is at `top_y`. rect = (x, z, width, depth).
static func floor_rect(parent: Node3D, rect: Rect2, top_y: float, mat: Material, thickness: float = 1.0) -> StaticBody3D:
	var c := Vector3(rect.position.x + rect.size.x * 0.5, top_y - thickness * 0.5, rect.position.y + rect.size.y * 0.5)
	var b := box(parent, c, Vector3(rect.size.x, thickness, rect.size.y), mat)
	(b.get_child(1) as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return b


## Wall between two points on the ground (base at from.y).
static func wall(parent: Node3D, from: Vector3, to: Vector3, height: float, thickness: float, mat: Material) -> StaticBody3D:
	var d := to - from
	d.y = 0.0
	var length := d.length()
	var mid := (from + to) * 0.5
	var yaw := rad_to_deg(atan2(d.x, d.z))
	var b := box(parent, Vector3(mid.x, from.y + height * 0.5, mid.z), Vector3(thickness, height, length + thickness), mat, CombatTypes.LAYER_WORLD, yaw)
	# Cornice band on top.
	mesh(b, _box_mesh(Vector3(thickness + 0.24, 0.22, length + thickness + 0.24)), Mats.get_mat(&"sandstone"), Vector3(0, height * 0.5 - 0.11, 0))
	return b


## Lotus-capital column with a base and a solid cylinder collider.
static func column(parent: Node3D, pos: Vector3, height: float = 5.0, radius: float = 0.55, shaft_mat: Material = null, cap_mat: Material = null) -> StaticBody3D:
	var sm := shaft_mat if shaft_mat != null else Mats.get_mat(&"sandstone_glyph")
	var cm := cap_mat if cap_mat != null else Mats.get_mat(&"turquoise_stone")
	var body := StaticBody3D.new()
	body.collision_layer = CombatTypes.LAYER_WORLD
	body.collision_mask = 0
	body.position = pos
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = radius * 1.05
	shape.height = height
	cs.shape = shape
	cs.position = Vector3(0, height * 0.5, 0)
	body.add_child(cs)
	parent.add_child(body)
	var shaft_h := height - 1.1
	mesh(body, _cyl_mesh(radius * 1.25, radius * 1.3, 0.3, 20), Mats.get_mat(&"sandstone"), Vector3(0, 0.15, 0))
	mesh(body, _cyl_mesh(radius * 0.92, radius, shaft_h, 20), sm, Vector3(0, 0.3 + shaft_h * 0.5, 0))
	# Bands below the capital.
	for i in 3:
		mesh(body, _cyl_mesh(radius * 0.97, radius * 0.97, 0.06, 20), Mats.get_mat(&"gold_world"), Vector3(0, 0.3 + shaft_h - 0.12 - i * 0.12, 0))
	# Lotus capital: flared bowl + petals + abacus.
	var cap_y := 0.3 + shaft_h
	mesh(body, _cyl_mesh(radius * 1.55, radius * 0.92, 0.6, 20), cm, Vector3(0, cap_y + 0.3, 0))
	for i in 8:
		var a := TAU * float(i) / 8.0
		var p := Vector3(cos(a), 0, sin(a)) * radius * 1.12
		mesh(body, _box_mesh(Vector3(0.18, 0.55, 0.08)), Mats.get_mat(&"lapis"), Vector3(p.x, cap_y + 0.32, p.z), Vector3(-18, -rad_to_deg(a) + 90.0, 0))
	mesh(body, _box_mesh(Vector3(radius * 2.4, 0.2, radius * 2.4)), Mats.get_mat(&"sandstone"), Vector3(0, height - 0.1, 0))
	return body


## Straight stairs from `bottom` (centre of first step, at its floor height) to `top`.
## Visual steps + an invisible smooth ramp collider (good for movement and navmesh).
static func stairs(parent: Node3D, bottom: Vector3, top: Vector3, width: float, mat: Material, side_walls: bool = true) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	var d := top - bottom
	var flat := Vector3(d.x, 0.0, d.z)
	var run := flat.length()
	var rise := d.y
	var yaw := atan2(flat.x, flat.z)
	root.position = bottom
	root.rotation = Vector3(0, yaw, 0)
	var steps := maxi(2, int(round(absf(rise) / 0.25)))
	var step_run := run / float(steps)
	var step_rise := rise / float(steps)
	for i in steps:
		var h := absf(step_rise) * float(i + 1) if rise > 0.0 else absf(rise) - absf(step_rise) * float(i)
		var z := step_run * (float(i) + 0.5)
		mesh(root, _box_mesh(Vector3(width, maxf(h, 0.05), step_run + 0.02)), mat,
			Vector3(0, minf(0.0, rise) + h * 0.5, z), Vector3.ZERO, Vector3.ONE, false)
	# Ramp collider: a thin rotated box along the slope.
	var body := StaticBody3D.new()
	body.collision_layer = CombatTypes.LAYER_WORLD
	body.collision_mask = 0
	root.add_child(body)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	var slope_len := sqrt(run * run + rise * rise)
	shape.size = Vector3(width, 0.4, slope_len + 0.3)
	cs.shape = shape
	var pitch := atan2(rise, run)
	cs.rotation = Vector3(-pitch, 0, 0)
	cs.position = Vector3(0, rise * 0.5 - 0.2 * cos(pitch), run * 0.5)
	body.add_child(cs)
	if side_walls:
		var hi := maxf(rise, 0.0) + 1.0
		for side in [-1.0, 1.0]:
			var wb := StaticBody3D.new()
			wb.collision_layer = CombatTypes.LAYER_WORLD
			root.add_child(wb)
			var wcs := CollisionShape3D.new()
			var ws := BoxShape3D.new()
			ws.size = Vector3(0.5, hi + absf(minf(rise, 0.0)), run)
			wcs.shape = ws
			wcs.position = Vector3(side * (width * 0.5 + 0.25), minf(rise, 0.0) + ws.size.y * 0.5, run * 0.5)
			wb.add_child(wcs)
			mesh(wb, _box_mesh(ws.size), Mats.get_mat(&"sandstone"), wcs.position)
	return root


static func obelisk(parent: Node3D, pos: Vector3, height: float = 7.0, mat: Material = null) -> StaticBody3D:
	var m := mat if mat != null else Mats.get_mat(&"basalt_glyph")
	var base_w := height * 0.13
	var body := box(parent, pos + Vector3(0, 0.3, 0), Vector3(base_w * 1.8, 0.6, base_w * 1.8), Mats.get_mat(&"sandstone"))
	var shaft := MeshInstance3D.new()
	var cm := _cyl_mesh(base_w * 0.5, base_w * 0.72, height, 4)
	shaft.mesh = cm
	shaft.material_override = m
	shaft.position = Vector3(0, 0.3 + height * 0.5, 0)
	shaft.rotation_degrees = Vector3(0, 45, 0)
	body.add_child(shaft)
	var tip := MeshInstance3D.new()
	tip.mesh = _cyl_mesh(0.0, base_w * 0.5, base_w * 0.8, 4)
	tip.material_override = Mats.get_mat(&"gold_world")
	tip.position = Vector3(0, 0.3 + height + base_w * 0.4, 0)
	tip.rotation_degrees = Vector3(0, 45, 0)
	body.add_child(tip)
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(base_w * 1.0, height, base_w * 1.0)
	cs.shape = s
	cs.position = Vector3(0, 0.3 + height * 0.5, 0)
	body.add_child(cs)
	return body


## Seated colossus (optionally broken: missing head/arm, rubble around).
static func statue(parent: Node3D, pos: Vector3, yaw_deg: float, scale_k: float = 1.0, broken: bool = false, jackal: bool = false) -> StaticBody3D:
	var stone := Mats.get_mat(&"sandstone")
	var body := StaticBody3D.new()
	body.collision_layer = CombatTypes.LAYER_WORLD
	body.position = pos
	body.rotation_degrees = Vector3(0, yaw_deg, 0)
	body.scale = Vector3.ONE * scale_k
	parent.add_child(body)
	var cs := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(2.0, 4.6, 2.6)
	cs.shape = s
	cs.position = Vector3(0, 2.3, 0)
	body.add_child(cs)
	mesh(body, _box_mesh(Vector3(2.2, 0.8, 2.8)), stone, Vector3(0, 0.4, 0))           # plinth
	mesh(body, _box_mesh(Vector3(1.8, 1.0, 1.4)), stone, Vector3(0, 1.3, 0.4))         # throne seat
	mesh(body, _box_mesh(Vector3(1.8, 2.2, 0.4)), stone, Vector3(0, 2.2, 1.0))         # throne back
	mesh(body, _box_mesh(Vector3(0.5, 1.0, 0.5)), stone, Vector3(0.4, 1.3, -0.45))     # shins
	mesh(body, _box_mesh(Vector3(0.5, 1.0, 0.5)), stone, Vector3(-0.4, 1.3, -0.45))
	mesh(body, _box_mesh(Vector3(1.4, 0.4, 1.3)), stone, Vector3(0, 2.0, 0.1))         # lap
	mesh(body, _box_mesh(Vector3(1.2, 1.5, 0.8)), stone, Vector3(0, 2.9, 0.4))         # torso
	mesh(body, _box_mesh(Vector3(0.32, 1.0, 0.32)), stone, Vector3(0.75, 2.6, 0.2), Vector3(-60, 0, 0))
	if not broken:
		mesh(body, _box_mesh(Vector3(0.32, 1.0, 0.32)), stone, Vector3(-0.75, 2.6, 0.2), Vector3(-60, 0, 0))
		if jackal:
			mesh(body, _box_mesh(Vector3(0.55, 0.6, 0.6)), Mats.get_mat(&"basalt"), Vector3(0, 3.95, 0.35))
			mesh(body, _box_mesh(Vector3(0.3, 0.25, 0.6)), Mats.get_mat(&"basalt"), Vector3(0, 3.85, -0.1))
			mesh(body, Kit._cyl_mesh(0.0, 0.12, 0.55, 4), Mats.get_mat(&"basalt"), Vector3(0.18, 4.45, 0.4))
			mesh(body, Kit._cyl_mesh(0.0, 0.12, 0.55, 4), Mats.get_mat(&"basalt"), Vector3(-0.18, 4.45, 0.4))
		else:
			mesh(body, _box_mesh(Vector3(0.6, 0.7, 0.6)), stone, Vector3(0, 4.0, 0.35))      # head
			mesh(body, _box_mesh(Vector3(0.95, 0.9, 0.7)), Mats.get_mat(&"lapis"), Vector3(0, 4.15, 0.45))   # nemes
			mesh(body, _box_mesh(Vector3(0.2, 0.45, 0.15)), Mats.get_mat(&"gold_world"), Vector3(0, 3.55, 0.05))
	else:
		mesh(body, _box_mesh(Vector3(0.7, 0.5, 0.6)), stone, Vector3(1.6, 0.25, -1.4), Vector3(12, 30, 8))
		mesh(body, _box_mesh(Vector3(0.6, 0.6, 0.6)), stone, Vector3(-1.3, 0.3, -1.6), Vector3(5, -20, 25))
		mesh(body, _box_mesh(Vector3(0.95, 0.9, 0.7)), Mats.get_mat(&"lapis"), Vector3(-1.8, 0.45, -0.4), Vector3(70, 10, 20))
	return body


## Torch on a wall: bracket, emissive flame, flickering light and embers.
## `facing` = direction the torch points (away from the wall).
static func torch(parent: Node3D, pos: Vector3, facing: Vector3, energy: float = 2.4, light_range: float = 7.5, shadows: bool = false) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	parent.add_child(root)
	var f := facing.normalized()
	mesh(root, _cyl_mesh(0.05, 0.03, 0.5, 6), Mats.get_mat(&"bronze"), f * 0.15 + Vector3(0, -0.1, 0), Vector3(25.0 * f.z, 0, -25.0 * f.x), Vector3.ONE, false)
	mesh(root, _cyl_mesh(0.12, 0.07, 0.14, 8), Mats.get_mat(&"bronze"), f * 0.28 + Vector3(0, 0.12, 0), Vector3.ZERO, Vector3.ONE, false)
	_flame(root, f * 0.28 + Vector3(0, 0.3, 0), 1.0)
	var light := TorchLight.new()
	light.position = f * 0.6 + Vector3(0, 0.4, 0)
	light.light_color = Color(1.0, 0.62, 0.3)
	light.base_energy = energy
	light.omni_range = light_range
	light.omni_attenuation = 1.2
	light.shadow_enabled = shadows
	light.light_volumetric_fog_energy = 1.5
	root.add_child(light)
	_embers(root, f * 0.28 + Vector3(0, 0.35, 0))
	return root


## Standing brazier (bowl on a tripod) with fire.
static func brazier(parent: Node3D, pos: Vector3, energy: float = 3.0, light_range: float = 9.0, shadows: bool = false, color: Color = Color(1.0, 0.6, 0.28)) -> StaticBody3D:
	var body := StaticBody3D.new()
	body.collision_layer = CombatTypes.LAYER_WORLD
	body.position = pos
	parent.add_child(body)
	var cs := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = 0.45
	s.height = 1.2
	cs.shape = s
	cs.position = Vector3(0, 0.6, 0)
	body.add_child(cs)
	mesh(body, _cyl_mesh(0.12, 0.3, 0.9, 8), Mats.get_mat(&"basalt"), Vector3(0, 0.45, 0))
	mesh(body, _cyl_mesh(0.55, 0.3, 0.3, 12), Mats.get_mat(&"bronze"), Vector3(0, 1.05, 0))
	_flame(body, Vector3(0, 1.35, 0), 1.8)
	var light := TorchLight.new()
	light.position = Vector3(0, 1.9, 0)
	light.light_color = color
	light.base_energy = energy
	light.omni_range = light_range
	light.shadow_enabled = shadows
	light.light_volumetric_fog_energy = 1.5
	body.add_child(light)
	_embers(body, Vector3(0, 1.4, 0))
	return body


static func _flame(parent: Node3D, pos: Vector3, size: float) -> void:
	if _flame_mat == null:
		_flame_mat = StandardMaterial3D.new()
		_flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_flame_mat.albedo_color = Color(1.0, 0.6, 0.2)
		_flame_mat.emission_enabled = true
		_flame_mat.emission = Color(1.0, 0.55, 0.15)
		_flame_mat.emission_energy_multiplier = 6.0
	var fl := mesh(parent, _cyl_mesh(0.0, 0.11 * size, 0.38 * size, 6), _flame_mat, pos, Vector3.ZERO, Vector3.ONE, false)
	fl.set_script(load("res://scripts/world/flame_wobble.gd"))
	mesh(parent, _cyl_mesh(0.0, 0.07 * size, 0.24 * size, 6), Mats.get_mat(&"sun"), pos + Vector3(0, -0.04, 0), Vector3.ZERO, Vector3.ONE, false)


static func _embers(parent: Node3D, pos: Vector3) -> void:
	if _ember_proc == null:
		_ember_proc = ParticleProcessMaterial.new()
		_ember_proc.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
		_ember_proc.emission_sphere_radius = 0.1
		_ember_proc.direction = Vector3.UP
		_ember_proc.spread = 25.0
		_ember_proc.initial_velocity_min = 0.6
		_ember_proc.initial_velocity_max = 1.6
		_ember_proc.gravity = Vector3(0, 0.6, 0)
		_ember_proc.turbulence_enabled = true
		_ember_proc.turbulence_noise_strength = 0.6
		_ember_proc.scale_min = 0.4
		_ember_proc.scale_max = 1.0
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.6, 1.0])
		g.colors = PackedColorArray([Color(1.0, 0.8, 0.4, 1.0), Color(1.0, 0.45, 0.1, 0.8), Color(0.6, 0.15, 0.05, 0.0)])
		var gt := GradientTexture1D.new()
		gt.gradient = g
		_ember_proc.color_ramp = gt
		_ember_mesh = QuadMesh.new()
		_ember_mesh.size = Vector2(0.05, 0.05)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_color = Color(2.0, 1.4, 0.8)
		_ember_mesh.material = m
	var p := GPUParticles3D.new()
	p.amount = 10
	p.lifetime = 1.6
	p.process_material = _ember_proc
	p.draw_pass_1 = _ember_mesh
	p.position = pos
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 5, 4))
	parent.add_child(p)


## Egyptian doorway (two pylons + lintel). Opening is centred on `pos`, facing `yaw`.
static func arch(parent: Node3D, pos: Vector3, yaw_deg: float, opening: float = 3.0, height: float = 4.0, depth: float = 1.2) -> Node3D:
	var root := Node3D.new()
	root.position = pos
	root.rotation_degrees = Vector3(0, yaw_deg, 0)
	parent.add_child(root)
	var pw := 1.0
	for side in [-1.0, 1.0]:
		box(root, Vector3(side * (opening * 0.5 + pw * 0.5), height * 0.5, 0), Vector3(pw, height, depth), Mats.get_mat(&"sandstone_glyph"))
	box(root, Vector3(0, height + 0.35, 0), Vector3(opening + pw * 2.0 + 0.3, 0.7, depth + 0.2), Mats.get_mat(&"sandstone"))
	# Winged sun disc on the lintel.
	mesh(root, _cyl_mesh(0.28, 0.28, 0.08, 16), Mats.get_mat(&"gold_world"), Vector3(0, height + 0.35, -depth * 0.5 - 0.11), Vector3(90, 0, 0))
	for side in [-1.0, 1.0]:
		mesh(root, _box_mesh(Vector3(0.9, 0.16, 0.05)), Mats.get_mat(&"lapis"), Vector3(side * 0.75, height + 0.38, -depth * 0.5 - 0.12), Vector3(0, 0, side * -8.0))
	return root


## Scattered rubble blocks (decorative, with collision for big ones).
static func rubble(parent: Node3D, center: Vector3, count: int, spread: float, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for i in count:
		var s := rng.randf_range(0.3, 0.8)
		var p := center + Vector3(rng.randf_range(-spread, spread), s * 0.4, rng.randf_range(-spread, spread))
		mesh(parent, _box_mesh(Vector3(s, s * 0.8, s * 1.1)), Mats.get_mat(&"sandstone"), p, Vector3(rng.randf_range(-20, 20), rng.randf_range(0, 360), rng.randf_range(-20, 20)))


## Sand drift: low flattened mound (visual only).
static func sand_drift(parent: Node3D, center: Vector3, radius: float, height: float = 0.25) -> void:
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = height * 2.0
	sm.radial_segments = 16
	sm.rings = 6
	mesh(parent, sm, Mats.get_mat(&"sand"), center, Vector3.ZERO, Vector3(1.0, 1.0, 0.7), false)
