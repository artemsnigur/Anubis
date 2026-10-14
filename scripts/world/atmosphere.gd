class_name Atmosphere
extends Node3D
## Owns the WorldEnvironment and the sun. Zones switch between presets with a tween:
##   courtyard - warm sunlight, light dust haze
##   tomb      - dark, cold ambient, dense volumetric fog lit by torches
##   hall      - the Hall of Two Truths, golden braziers
##   hall_rage - Ammit phase 2, red light
## ACES tonemapping, glow, SSAO, volumetric fog. Only the sun casts shadows by default.

signal preset_changed(preset_name: StringName)

const PRESETS: Dictionary = {
	&"courtyard": {
		"sun_energy": 1.7, "sun_color": Color(1.0, 0.86, 0.66),
		"ambient_color": Color(0.66, 0.58, 0.5), "ambient_energy": 0.55,
		"fog_density": 0.006, "fog_albedo": Color(1.0, 0.86, 0.68), "fog_emission": Color(0.0, 0.0, 0.0),
		"depth_fog": 0.002, "fog_color": Color(0.9, 0.78, 0.6),
		"exposure": 1.0, "glow": 0.55, "saturation": 1.08, "contrast": 1.05,
		"music": "music_courtyard", "ambience": "amb_wind", "reverb": 0.05,
	},
	&"tomb": {
		"sun_energy": 0.0, "sun_color": Color(1.0, 0.86, 0.66),
		"ambient_color": Color(0.16, 0.18, 0.28), "ambient_energy": 0.7,
		"fog_density": 0.035, "fog_albedo": Color(0.55, 0.5, 0.45), "fog_emission": Color(0.01, 0.012, 0.02),
		"depth_fog": 0.0, "fog_color": Color(0.1, 0.1, 0.14),
		"exposure": 1.25, "glow": 0.85, "saturation": 1.0, "contrast": 1.08,
		"music": "music_tomb", "ambience": "amb_tomb", "reverb": 0.3,
	},
	&"hall": {
		"sun_energy": 0.0, "sun_color": Color(1.0, 0.86, 0.66),
		"ambient_color": Color(0.3, 0.24, 0.16), "ambient_energy": 0.65,
		"fog_density": 0.022, "fog_albedo": Color(0.8, 0.65, 0.45), "fog_emission": Color(0.02, 0.014, 0.006),
		"depth_fog": 0.0, "fog_color": Color(0.2, 0.15, 0.1),
		"exposure": 1.15, "glow": 0.9, "saturation": 1.05, "contrast": 1.08,
		"music": "", "ambience": "amb_tomb", "reverb": 0.35,
	},
	&"hall_rage": {
		"sun_energy": 0.0, "sun_color": Color(1.0, 0.4, 0.3),
		"ambient_color": Color(0.45, 0.1, 0.06), "ambient_energy": 0.75,
		"fog_density": 0.03, "fog_albedo": Color(0.9, 0.35, 0.25), "fog_emission": Color(0.06, 0.008, 0.004),
		"depth_fog": 0.0, "fog_color": Color(0.3, 0.05, 0.03),
		"exposure": 1.2, "glow": 1.1, "saturation": 1.15, "contrast": 1.12,
		"music": "", "ambience": "amb_tomb", "reverb": 0.35,
	},
}

@export var initial_preset: StringName = &"courtyard"
@export var sun_pitch_deg: float = -52.0
@export var sun_yaw_deg: float = 32.0

var env: Environment
var sun: DirectionalLight3D
var current: StringName = &""
var _tween: Tween


func _ready() -> void:
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.32, 0.5, 0.78)
	sm.sky_horizon_color = Color(0.95, 0.8, 0.6)
	sm.ground_horizon_color = Color(0.8, 0.65, 0.45)
	sm.ground_bottom_color = Color(0.4, 0.3, 0.2)
	sm.sun_angle_max = 20.0
	sky.sky_material = sm
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 6.0
	env.glow_enabled = true
	env.glow_bloom = 0.05
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 1.6
	env.ssao_power = 1.4
	env.volumetric_fog_enabled = true
	env.volumetric_fog_length = 48.0
	env.volumetric_fog_anisotropy = 0.5
	env.volumetric_fog_gi_inject = 0.0
	env.volumetric_fog_ambient_inject = 0.3
	env.fog_enabled = true
	env.fog_sky_affect = 0.3
	env.adjustment_enabled = true
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(sun_pitch_deg, sun_yaw_deg, 0.0)
	sun.shadow_enabled = true
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 34.0
	sun.directional_shadow_blend_splits = true
	sun.light_volumetric_fog_energy = 1.2
	add_child(sun)
	apply_preset(initial_preset, true)


func apply_preset(preset: StringName, instant: bool = false, duration: float = 1.8) -> void:
	if not PRESETS.has(preset) or preset == current:
		return
	current = preset
	var p: Dictionary = PRESETS[preset]
	if _tween != null and _tween.is_valid():
		_tween.kill()
	var props := {
		"light_energy": [sun, p["sun_energy"]],
		"light_color": [sun, p["sun_color"]],
	}
	var env_props := {
		"ambient_light_color": p["ambient_color"],
		"ambient_light_energy": p["ambient_energy"],
		"volumetric_fog_density": p["fog_density"],
		"volumetric_fog_albedo": p["fog_albedo"],
		"volumetric_fog_emission": p["fog_emission"],
		"fog_density": p["depth_fog"],
		"fog_light_color": p["fog_color"],
		"tonemap_exposure": p["exposure"],
		"glow_intensity": p["glow"],
		"adjustment_saturation": p["saturation"],
		"adjustment_contrast": p["contrast"],
	}
	if instant:
		for k: String in props:
			(props[k][0] as Object).set(k, props[k][1])
		for k: String in env_props:
			env.set(k, env_props[k])
	else:
		_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_SINE)
		for k: String in props:
			_tween.tween_property(props[k][0] as Object, k, props[k][1], duration)
		for k: String in env_props:
			_tween.tween_property(env, k, env_props[k], duration)
	sun.visible = float(p["sun_energy"]) > 0.01 or not instant
	var music: String = p["music"]
	if music != "":
		AudioManager.play_music(music, 3.0)
	AudioManager.play_ambience(String(p["ambience"]))
	AudioManager.set_reverb(float(p["reverb"]))
	preset_changed.emit(preset)
