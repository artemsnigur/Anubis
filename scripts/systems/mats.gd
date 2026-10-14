class_name Mats
extends RefCounted
## Shared material library (created once, reused everywhere).
## World materials use world.gdshader (triplanar + dithered occlusion fade),
## characters use StandardMaterial3D or small dedicated shaders.

const WORLD_SHADER := preload("res://assets/shaders/world.gdshader")
const FAIENCE_SHADER := preload("res://assets/shaders/faience.gdshader")
const LINEN_SHADER := preload("res://assets/shaders/linen.gdshader")
const NOISE_STONE := preload("res://assets/textures/noise_stone.png")
const NOISE_FINE := preload("res://assets/textures/noise_fine.png")
const GLYPHS := preload("res://assets/textures/hieroglyphs.png")

static var _cache: Dictionary = {}


static func get_mat(mat_name: StringName) -> Material:
	if _cache.has(mat_name):
		return _cache[mat_name]
	var m := _create(mat_name)
	_cache[mat_name] = m
	return m


static func _create(mat_name: StringName) -> Material:
	match mat_name:
		# --- world ---
		&"sandstone":
			return _world(Color(0.80, 0.64, 0.42), Color(0.60, 0.45, 0.28), {"strata_strength": 0.16})
		&"sandstone_glyph":
			return _world(Color(0.80, 0.64, 0.42), Color(0.60, 0.45, 0.28), {"strata_strength": 0.12, "glyph_strength": 0.75})
		&"sandstone_floor":
			return _world(Color(0.80, 0.65, 0.44), Color(0.68, 0.53, 0.34), {"strata_strength": 0.0, "occluder": false, "sand_cover": 0.55, "tex_scale": 0.12, "tile_size": 1.6, "noise_contrast": 0.6, "glitter": 0.4})
		&"sand":
			return _world(Color(0.88, 0.73, 0.49), Color(0.79, 0.63, 0.40), {"strata_strength": 0.0, "occluder": false, "roughness_value": 1.0, "tex_scale": 0.08, "detail_scale": 0.7, "noise_contrast": 0.55})
		&"tomb_floor":
			return _world(Color(0.42, 0.34, 0.25), Color(0.30, 0.24, 0.17), {"strata_strength": 0.0, "occluder": false, "sand_cover": 0.25, "sand_color": Color(0.55, 0.43, 0.28), "tile_size": 1.2, "noise_contrast": 0.7, "grout_color": Color(0.12, 0.09, 0.06)})
		&"tomb_wall":
			return _world(Color(0.55, 0.44, 0.31), Color(0.38, 0.29, 0.19), {"strata_strength": 0.2, "glyph_strength": 0.8, "glyph_color": Color(0.12, 0.08, 0.05)})
		&"tomb_wall_plain":
			return _world(Color(0.55, 0.44, 0.31), Color(0.38, 0.29, 0.19), {"strata_strength": 0.2})
		&"tomb_block":
			return _world(Color(0.62, 0.5, 0.35), Color(0.44, 0.34, 0.23), {"strata_strength": 0.18, "glyph_strength": 0.9, "glyph_painted": true,
				"glyph_band_min": -3.45, "glyph_band_max": -1.95, "frieze": 1.0, "top_mix": 1.0, "top_color": Color(0.16, 0.13, 0.11), "glyph_scale": 0.55})
		&"courtyard_wall":
			return _world(Color(0.82, 0.66, 0.44), Color(0.64, 0.49, 0.31), {"strata_strength": 0.16, "glyph_strength": 0.65, "glyph_painted": true,
				"glyph_band_min": 0.9, "glyph_band_max": 3.4, "frieze": 0.7, "glyph_color": Color(0.35, 0.2, 0.1)})
		&"desert":
			return _world(Color(0.9, 0.74, 0.5), Color(0.8, 0.63, 0.4), {"strata_strength": 0.0, "occluder": false, "roughness_value": 1.0, "tex_scale": 0.06,
				"detail_scale": 0.7, "noise_contrast": 0.6, "ripple_strength": 1.0, "ripple_scale": 1.3, "glitter": 1.0})
		&"hall_wall":
			return _world(Color(0.1, 0.1, 0.12), Color(0.05, 0.05, 0.06), {"strata_strength": 0.0, "roughness_value": 0.4, "glyph_strength": 0.95,
				"glyph_color": Color(1.0, 0.72, 0.28), "glyph_emission": 1.4, "glyph_band_min": -3.5, "glyph_band_max": -1.5, "glyph_scale": 0.5, "frieze": 0.0, "top_mix": 1.0, "top_color": Color(0.06, 0.05, 0.05)})
		&"lapis":
			return _world(Color(0.10, 0.18, 0.55), Color(0.05, 0.09, 0.33), {"strata_strength": 0.0, "fleck_amount": 1.0, "roughness_value": 0.35, "specular_value": 0.6, "detail_scale": 2.5})
		&"basalt":
			return _world(Color(0.10, 0.10, 0.11), Color(0.05, 0.05, 0.06), {"strata_strength": 0.0, "roughness_value": 0.45, "specular_value": 0.55})
		&"basalt_glyph":
			return _world(Color(0.10, 0.10, 0.11), Color(0.05, 0.05, 0.06), {"strata_strength": 0.0, "roughness_value": 0.45, "glyph_strength": 0.9, "glyph_color": Color(0.95, 0.72, 0.3), "glyph_emission": 0.6})
		&"terracotta":
			return _world(Color(0.70, 0.36, 0.20), Color(0.52, 0.24, 0.13), {"strata_strength": 0.05, "roughness_value": 0.9})
		&"turquoise_stone":
			return _world(Color(0.20, 0.68, 0.64), Color(0.08, 0.42, 0.44), {"strata_strength": 0.0, "roughness_value": 0.3, "specular_value": 0.6})
		&"gold_world":
			return _world(Color(1.0, 0.72, 0.26), Color(0.85, 0.55, 0.16), {"strata_strength": 0.0, "metallic_value": 0.9, "roughness_value": 0.36, "specular_value": 0.7, "noise_contrast": 0.5})
		&"hall_floor":
			return _world(Color(0.12, 0.13, 0.15), Color(0.06, 0.06, 0.08), {"strata_strength": 0.0, "occluder": false, "roughness_value": 0.42, "specular_value": 0.5, "sand_cover": 0.0, "tile_size": 2.0, "grout_color": Color(0.7, 0.55, 0.25), "tile_variation": 0.3, "noise_contrast": 0.5, "normal_strength": 0.15})
		# --- characters / props ---
		&"faience":
			var f := ShaderMaterial.new()
			f.shader = FAIENCE_SHADER
			return f
		&"linen":
			var l := ShaderMaterial.new()
			l.shader = LINEN_SHADER
			return l
		&"gold":
			return _std(Color(1.0, 0.72, 0.26), 0.9, 0.32)
		&"bronze":
			return _std(Color(0.80, 0.52, 0.26), 1.0, 0.32)
		&"lapis_char":
			return _std(Color(0.08, 0.15, 0.5), 0.0, 0.35)
		&"black_glaze":
			return _std(Color(0.04, 0.04, 0.05), 0.0, 0.25)
		&"jackal":
			return _std(Color(0.07, 0.065, 0.07), 0.1, 0.55)
		&"kilt":
			return _std(Color(0.78, 0.74, 0.62), 0.0, 0.85)
		&"red_cloth":
			return _std(Color(0.55, 0.10, 0.08), 0.0, 0.8)
		&"cobra":
			return _std(Color(0.16, 0.42, 0.22), 0.2, 0.45)
		&"cobra_belly":
			return _std(Color(0.78, 0.70, 0.38), 0.1, 0.55)
		&"priestess_skin":
			return _std(Color(0.55, 0.36, 0.22), 0.0, 0.6)
		&"scarab":
			var s := _std(Color(0.06, 0.16, 0.14), 0.75, 0.25)
			s.rim_enabled = true
			s.rim = 0.6
			s.rim_tint = 0.2
			return s
		&"croc":
			return _std(Color(0.26, 0.36, 0.2), 0.0, 0.6)
		&"croc_belly":
			return _std(Color(0.55, 0.52, 0.34), 0.0, 0.75)
		&"lion":
			return _std(Color(0.82, 0.58, 0.28), 0.0, 0.8)
		&"mane":
			return _std(Color(0.45, 0.25, 0.10), 0.0, 0.95)
		&"hippo":
			return _std(Color(0.5, 0.42, 0.42), 0.0, 0.6)
		&"teeth":
			return _std(Color(0.95, 0.92, 0.8), 0.0, 0.4)
		&"bone":
			return _std(Color(0.88, 0.84, 0.72), 0.0, 0.7)
		&"wood":
			return _std(Color(0.40, 0.26, 0.14), 0.0, 0.8)
		&"eye_glow":
			return _emissive(Color(0.3, 1.0, 0.85), 4.0)
		&"eye_red":
			return _emissive(Color(1.0, 0.25, 0.1), 5.0)
		&"eye_gold":
			return _emissive(Color(1.0, 0.75, 0.25), 4.0)
		&"venom":
			return _emissive(Color(0.45, 1.0, 0.25), 2.5)
		&"heart_glow":
			return _emissive(Color(1.0, 0.25, 0.2), 3.0)
		&"osiris_flame":
			return _emissive(Color(0.25, 1.0, 0.55), 5.0)
		&"sun":
			return _emissive(Color(1.0, 0.8, 0.35), 6.0)
		&"feather":
			return _std(Color(0.95, 0.95, 0.9), 0.0, 0.6)
	push_warning("Mats: unknown material '%s'" % mat_name)
	return _std(Color.MAGENTA, 0.0, 0.5)


static func _world(a: Color, b: Color, params: Dictionary) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = WORLD_SHADER
	m.set_shader_parameter(&"color_a", a)
	m.set_shader_parameter(&"color_b", b)
	m.set_shader_parameter(&"noise_tex", NOISE_STONE)
	m.set_shader_parameter(&"glyph_tex", GLYPHS)
	for k: String in params:
		m.set_shader_parameter(StringName(k), params[k])
	return m


static func _std(c: Color, metallic: float, roughness: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.metallic = metallic
	m.roughness = roughness
	# Soft rim so characters separate from dark floors under the top-down camera.
	m.rim_enabled = true
	m.rim = 0.35
	m.rim_tint = 0.4
	return m


static func _emissive(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## A unique world material instance (for tinted variants).
static func world_custom(a: Color, b: Color, params: Dictionary) -> ShaderMaterial:
	return _world(a, b, params)
