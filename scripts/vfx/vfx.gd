extends Node
## VFX service: one-shot particle bursts, glints, shockwave rings, ground telegraphs,
## light flashes and Ka orbs. Materials are built once and shared.

const RING_SHADER := preload("res://assets/shaders/dissolve_ring.gdshader")

var _proc: Dictionary = {}    # effect -> ParticleProcessMaterial
var _draw: Dictionary = {}    # effect -> Mesh
var _soft_tex: ImageTexture
var _star_tex: ImageTexture
var _star_mat: StandardMaterial3D
var _orb_mesh: SphereMesh
var _orb_mat: StandardMaterial3D
var _plane: PlaneMesh


func _ready() -> void:
	_soft_tex = _make_soft_texture(64)
	_star_tex = _make_star_texture(128)
	_build_effects()
	_star_mat = StandardMaterial3D.new()
	_star_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_star_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_star_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_star_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_star_mat.albedo_texture = _star_tex
	_star_mat.no_depth_test = true
	_star_mat.render_priority = 10
	_orb_mesh = SphereMesh.new()
	_orb_mesh.radius = 0.07
	_orb_mesh.height = 0.14
	_orb_mesh.radial_segments = 8
	_orb_mesh.rings = 4
	_orb_mat = StandardMaterial3D.new()
	_orb_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_orb_mat.albedo_color = Color(0.55, 1.0, 0.85)
	_orb_mat.emission_enabled = true
	_orb_mat.emission = Color(0.4, 1.0, 0.8)
	_orb_mat.emission_energy_multiplier = 4.0
	_plane = PlaneMesh.new()
	_plane.size = Vector2(2.0, 2.0)


func _root() -> Node:
	var scene := get_tree().current_scene
	return scene if scene != null else get_tree().root


# --- textures ---------------------------------------------------------------------

func _make_soft_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size - 1) * 0.5
	for y in size:
		for x in size:
			var d := Vector2(x - c, y - c).length() / c
			var a := clampf(1.0 - d, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a * a))
	return ImageTexture.create_from_image(img)


func _make_star_texture(size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	var c := float(size - 1) * 0.5
	for y in size:
		for x in size:
			var p := Vector2(x - c, y - c) / c
			var r := p.length()
			var core := pow(clampf(1.0 - r * 2.2, 0.0, 1.0), 2.0)
			var beam_h := pow(clampf(1.0 - absf(p.y) * 18.0, 0.0, 1.0), 2.0) * clampf(1.0 - absf(p.x), 0.0, 1.0)
			var beam_v := pow(clampf(1.0 - absf(p.x) * 18.0, 0.0, 1.0), 2.0) * clampf(1.0 - absf(p.y), 0.0, 1.0)
			var a := clampf(core + beam_h + beam_v, 0.0, 1.0)
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


# --- effect definitions -----------------------------------------------------------

func _billboard_mat(additive: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if additive:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = _soft_tex
	return m


func _quad(size: float, mat: Material) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = mat
	return q


func _gradient(colors: Array[Color]) -> GradientTexture1D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for i in colors.size():
		offs.append(float(i) / float(maxi(colors.size() - 1, 1)))
		cols.append(colors[i])
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture1D.new()
	t.gradient = g
	return t


func _curve(points: Array[Vector2]) -> CurveTexture:
	var c := Curve.new()
	for p in points:
		c.add_point(p)
	var t := CurveTexture.new()
	t.curve = c
	return t


func _build_effects() -> void:
	# Sparks: streaks aligned to velocity.
	var spark_pm := ParticleProcessMaterial.new()
	spark_pm.direction = Vector3(0, 0, -1)
	spark_pm.spread = 55.0
	spark_pm.initial_velocity_min = 5.0
	spark_pm.initial_velocity_max = 11.0
	spark_pm.gravity = Vector3(0, -12, 0)
	spark_pm.damping_min = 4.0
	spark_pm.damping_max = 8.0
	spark_pm.particle_flag_align_y = true
	spark_pm.scale_min = 0.6
	spark_pm.scale_max = 1.2
	spark_pm.scale_curve = _curve([Vector2(0, 1), Vector2(1, 0)])
	spark_pm.color_ramp = _gradient([Color(1, 1, 0.9, 1), Color(1, 0.7, 0.25, 1), Color(1, 0.4, 0.1, 0)])
	_proc[&"sparks"] = spark_pm
	var spark_mesh := BoxMesh.new()
	spark_mesh.size = Vector3(0.025, 0.32, 0.025)
	var spark_mat := StandardMaterial3D.new()
	spark_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	spark_mat.vertex_color_use_as_albedo = true
	spark_mat.albedo_color = Color(3.0, 2.2, 1.2)
	spark_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	spark_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	spark_mesh.material = spark_mat
	_draw[&"sparks"] = spark_mesh

	# Sand burst: soft puffs.
	var sand_pm := ParticleProcessMaterial.new()
	sand_pm.direction = Vector3(0, 0.4, -1)
	sand_pm.spread = 70.0
	sand_pm.initial_velocity_min = 1.5
	sand_pm.initial_velocity_max = 4.5
	sand_pm.gravity = Vector3(0, -4, 0)
	sand_pm.damping_min = 3.0
	sand_pm.damping_max = 5.0
	sand_pm.scale_min = 0.6
	sand_pm.scale_max = 1.4
	sand_pm.scale_curve = _curve([Vector2(0, 0.4), Vector2(0.3, 1.0), Vector2(1, 1.3)])
	sand_pm.color_ramp = _gradient([Color(0.95, 0.8, 0.55, 0.9), Color(0.85, 0.68, 0.42, 0.5), Color(0.8, 0.62, 0.38, 0)])
	_proc[&"sand"] = sand_pm
	_draw[&"sand"] = _quad(0.45, _billboard_mat(false))

	# Dust: slow, low ring of puffs (footsteps, dodges, landings).
	var dust_pm := ParticleProcessMaterial.new()
	dust_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	dust_pm.emission_sphere_radius = 0.25
	dust_pm.direction = Vector3(0, 1, 0)
	dust_pm.spread = 80.0
	dust_pm.flatness = 0.7
	dust_pm.initial_velocity_min = 0.6
	dust_pm.initial_velocity_max = 1.8
	dust_pm.gravity = Vector3(0, 0.3, 0)
	dust_pm.damping_min = 2.0
	dust_pm.damping_max = 3.0
	dust_pm.scale_min = 0.6
	dust_pm.scale_max = 1.2
	dust_pm.scale_curve = _curve([Vector2(0, 0.5), Vector2(1, 1.5)])
	dust_pm.color_ramp = _gradient([Color(0.9, 0.78, 0.58, 0.55), Color(0.85, 0.72, 0.5, 0)])
	_proc[&"dust"] = dust_pm
	_draw[&"dust"] = _quad(0.6, _billboard_mat(false))

	# Faience shards_pm: tumbling turquoise chips (hero takes damage).
	var shards_pm := ParticleProcessMaterial.new()
	shards_pm.direction = Vector3(0, 0.6, -1)
	shards_pm.spread = 60.0
	shards_pm.initial_velocity_min = 3.0
	shards_pm.initial_velocity_max = 6.5
	shards_pm.gravity = Vector3(0, -16, 0)
	shards_pm.angular_velocity_min = -720.0
	shards_pm.angular_velocity_max = 720.0
	shards_pm.particle_flag_rotate_y = true
	shards_pm.scale_min = 0.5
	shards_pm.scale_max = 1.3
	shards_pm.scale_curve = _curve([Vector2(0, 1), Vector2(0.8, 1), Vector2(1, 0)])
	_proc[&"shards"] = shards_pm
	var shard_mesh := PrismMesh.new()
	shard_mesh.size = Vector3(0.09, 0.07, 0.03)
	var shard_mat := StandardMaterial3D.new()
	shard_mat.albedo_color = Color(0.2, 0.75, 0.72)
	shard_mat.metallic = 0.2
	shard_mat.roughness = 0.2
	shard_mat.emission_enabled = true
	shard_mat.emission = Color(0.1, 0.5, 0.5)
	shard_mesh.material = shard_mat
	_draw[&"shards"] = shard_mesh

	# Venom splash.
	var venom_pm := spark_pm.duplicate() as ParticleProcessMaterial
	venom_pm.color_ramp = _gradient([Color(0.7, 1.0, 0.3, 1), Color(0.3, 0.8, 0.1, 0.8), Color(0.2, 0.5, 0.1, 0)])
	venom_pm.initial_velocity_min = 2.0
	venom_pm.initial_velocity_max = 5.0
	venom_pm.spread = 80.0
	_proc[&"venom"] = venom_pm
	_draw[&"venom"] = _quad(0.22, _billboard_mat(true))

	# Embers / holy light motes_pm (heal, Ra impact, altar).
	var motes_pm := ParticleProcessMaterial.new()
	motes_pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	motes_pm.emission_sphere_radius = 0.5
	motes_pm.direction = Vector3(0, 1, 0)
	motes_pm.spread = 30.0
	motes_pm.initial_velocity_min = 1.0
	motes_pm.initial_velocity_max = 2.5
	motes_pm.gravity = Vector3(0, 0.5, 0)
	motes_pm.damping_min = 1.0
	motes_pm.damping_max = 2.0
	motes_pm.scale_min = 0.4
	motes_pm.scale_max = 1.0
	motes_pm.scale_curve = _curve([Vector2(0, 0.2), Vector2(0.2, 1), Vector2(1, 0)])
	_proc[&"motes"] = motes_pm
	_draw[&"motes"] = _quad(0.18, _billboard_mat(true))


# --- spawning --------------------------------------------------------------------

func _emit(effect: StringName, pos: Vector3, dir: Vector3, amount: int, lifetime: float, scale_mult: float = 1.0) -> GPUParticles3D:
	if not _proc.has(effect):
		return null
	var p := GPUParticles3D.new()
	p.process_material = _proc[effect]
	p.draw_pass_1 = _draw[effect]
	p.amount = maxi(amount, 1)
	p.lifetime = lifetime
	p.one_shot = true
	p.explosiveness = 1.0
	p.randomness = 0.5
	p.local_coords = false
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-6, -6, -6), Vector3(12, 12, 12))
	var basis := Basis.IDENTITY
	var d := dir
	if d.length_squared() > 0.0001:
		d = d.normalized()
		var up := Vector3.UP if absf(d.dot(Vector3.UP)) < 0.98 else Vector3.RIGHT
		basis = Basis.looking_at(d, up)
	p.transform = Transform3D(basis.scaled(Vector3.ONE * scale_mult), pos)
	_root().add_child(p)
	p.reset_physics_interpolation()
	p.emitting = true
	get_tree().create_timer(lifetime + 0.6, false).timeout.connect(p.queue_free)
	return p


func hit_sparks(pos: Vector3, dir: Vector3, heavy: bool = false) -> void:
	_emit(&"sparks", pos, dir, 26 if heavy else 16, 0.32)
	light_flash(pos, Color(1.0, 0.75, 0.4), 3.0 if heavy else 1.8, 4.0, 0.12)


func sand_burst(pos: Vector3, dir: Vector3, amount: int = 14) -> void:
	_emit(&"sand", pos, dir, amount, 0.7)


func dust(pos: Vector3, amount: int = 6, scale_mult: float = 1.0) -> void:
	_emit(&"dust", pos + Vector3.UP * 0.1, Vector3.UP, amount, 0.8, scale_mult)


func shards(pos: Vector3, dir: Vector3, amount: int = 12) -> void:
	_emit(&"shards", pos, dir, amount, 0.9)


func venom_splash(pos: Vector3) -> void:
	_emit(&"venom", pos, Vector3.UP, 18, 0.5)


func motes(pos: Vector3, amount: int = 16) -> void:
	_emit(&"motes", pos, Vector3.UP, amount, 1.2)


## Bright star flare used to telegraph enemy attacks and full heavy charge.
func glint(pos: Vector3, color: Color = Color(1.0, 0.85, 0.5), size: float = 1.1, duration: float = 0.28) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var mat := _star_mat.duplicate() as StandardMaterial3D
	mat.albedo_color = Color(color.r * 2.0, color.g * 2.0, color.b * 2.0, 1.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.scale = Vector3.ONE * 0.2
	_root().add_child(mi)
	mi.reset_physics_interpolation()
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 1.0, duration * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(mi, "rotation:z", 0.6, duration)
	tw.tween_property(mi, "scale", Vector3.ONE * 0.01, duration * 0.65).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	light_flash(pos, color, 2.5, 3.0, duration)


func light_flash(pos: Vector3, color: Color, energy: float, light_range: float, duration: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = color
	l.light_energy = energy
	l.omni_range = light_range
	l.shadow_enabled = false
	l.position = pos
	_root().add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, duration)
	tw.tween_callback(l.queue_free)


## Expanding flat ring (shockwaves, roars, landings).
func ring(pos: Vector3, from_radius: float, to_radius: float, duration: float, color: Color, thickness: float = 0.12) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _plane
	var mat := ShaderMaterial.new()
	mat.shader = RING_SHADER
	mat.set_shader_parameter(&"color", color)
	mat.set_shader_parameter(&"thickness", thickness)
	mat.set_shader_parameter(&"alpha", 1.0)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3.UP * 0.06
	mi.scale = Vector3(from_radius, 1.0, from_radius)
	_root().add_child(mi)
	mi.reset_physics_interpolation()
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(to_radius, 1.0, to_radius), duration).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.parallel().tween_method(func(a: float) -> void: mat.set_shader_parameter(&"alpha", a), 1.0, 0.0, duration).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi


## Ground circle that fills up over `duration` (burrow strike / AoE telegraph).
## Returns the node; it frees itself after the duration (+ hold).
func ground_telegraph(pos: Vector3, radius: float, duration: float, color: Color = Color(1.0, 0.35, 0.15), hold: float = 0.15) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = _plane
	var mat := ShaderMaterial.new()
	mat.shader = RING_SHADER
	mat.set_shader_parameter(&"color", color)
	mat.set_shader_parameter(&"thickness", 0.08)
	mat.set_shader_parameter(&"show_fill", true)
	mat.set_shader_parameter(&"fill", 0.0)
	mat.set_shader_parameter(&"alpha", 0.0)
	mat.set_shader_parameter(&"intensity", 1.6)
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3.UP * 0.07
	mi.scale = Vector3(radius, 1.0, radius)
	_root().add_child(mi)
	mi.reset_physics_interpolation()
	var tw := mi.create_tween()
	tw.tween_method(func(a: float) -> void: mat.set_shader_parameter(&"alpha", a), 0.0, 1.0, 0.12)
	tw.parallel().tween_method(func(f: float) -> void: mat.set_shader_parameter(&"fill", f), 0.0, 1.0, duration)
	tw.tween_interval(hold)
	tw.tween_method(func(a: float) -> void: mat.set_shader_parameter(&"alpha", a), 1.0, 0.0, 0.15)
	tw.tween_callback(mi.queue_free)
	return mi


## Glowing Ka motes flying from `from` into `target`.
func ka_orbs(from: Vector3, target: Node3D, count: int) -> void:
	if target == null:
		return
	for i in clampi(count, 1, 14):
		var mi := MeshInstance3D.new()
		mi.mesh = _orb_mesh
		mi.material_override = _orb_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = from + Vector3(randf_range(-0.4, 0.4), randf_range(0.6, 1.2), randf_range(-0.4, 0.4))
		_root().add_child(mi)
		mi.reset_physics_interpolation()
		var start := mi.position
		var ctrl := start + Vector3(randf_range(-2.0, 2.0), randf_range(1.5, 3.0), randf_range(-2.0, 2.0))
		var dur := randf_range(0.55, 0.9)
		var fly := func(t: float) -> void:
			if not is_instance_valid(target):
				return
			var end := target.global_position + Vector3.UP * 1.0
			var a := start.lerp(ctrl, t)
			var b := ctrl.lerp(end, t)
			mi.global_position = a.lerp(b, t)
		var tw := mi.create_tween()
		tw.tween_interval(0.05 * i)
		tw.tween_method(fly, 0.0, 1.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
		tw.tween_callback(mi.queue_free)


## Spawns every effect once far below the level so shaders compile before combat.
func prewarm() -> void:
	var p := Vector3(0, -200, 0)
	hit_sparks(p, Vector3.FORWARD)
	sand_burst(p, Vector3.FORWARD)
	dust(p)
	shards(p, Vector3.FORWARD)
	venom_splash(p)
	motes(p)
	glint(p)
	ring(p, 0.5, 1.0, 0.2, Color.WHITE)
