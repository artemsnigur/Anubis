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
		"sun_energy": 1.35, "sun_color": Color(1.0, 0.88, 0.7), "sun_shadows": true,
		"ambient_color": Color(0.58, 0.56, 0.6), "ambient_energy": 0.5,
		"fog_density": 0.005, "fog_albedo": Color(1.0, 0.88, 0.7), "fog_emission": Color(0.0, 0.0, 0.0),
		"depth_fog": 0.002, "fog_color": Color(0.9, 0.78, 0.6),
		"exposure": 0.92, "glow": 0.5, "saturation": 1.1, "contrast": 1.08,
		"music": "music_courtyard", "ambience": "amb_wind", "reverb": 0.05,
	},
	&"tomb": {
		"sun_energy": 0.22, "sun_color": Color(0.45, 0.58, 1.0), "sun_shadows": false,
		"ambient_color": Color(0.24, 0.27, 0.42), "ambient_energy": 0.9,
		"fog_density": 0.018, "fog_albedo": Color(0.5, 0.52, 0.6), "fog_emission": Color(0.006, 0.008, 0.016),
		"depth_fog": 0.0, "fog_color": Color(0.1, 0.1, 0.14),
		"exposure": 1.4, "glow": 0.8, "saturation": 1.08, "contrast": 1.1,
		"music": "music_tomb", "ambience": "amb_tomb", "reverb": 0.3,
	},
	&"hall": {
		"sun_energy": 0.25, "sun_color": Color(0.55, 0.6, 1.0), "sun_shadows": false,
		"ambient_color": Color(0.3, 0.26, 0.24), "ambient_energy": 0.85,
		"fog_density": 0.014, "fog_albedo": Color(0.8, 0.68, 0.5), "fog_emission": Color(0.014, 0.01, 0.005),
		"depth_fog": 0.0, "fog_color": Color(0.2, 0.15, 0.1),
		"exposure": 1.3, "glow": 0.9, "saturation": 1.08, "contrast": 1.1,
		"music": "", "ambience": "amb_tomb", "reverb": 0.35,
	},
	&"hall_rage": {
		"sun_energy": 0.3, "sun_color": Color(1.0, 0.3, 0.25), "sun_shadows": false,
		"ambient_color": Color(0.46, 0.2, 0.17), "ambient_energy": 0.85,
		"fog_density": 0.018, "fog_albedo": Color(0.85, 0.45, 0.35), "fog_emission": Color(0.035, 0.006, 0.003),
		"depth_fog": 0.0, "fog_color": Color(0.3, 0.05, 0.03),
		"exposure": 1.3, "glow": 1.1, "saturation": 1.15, "contrast": 1.14,
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
	sm.ground_horizon_color = Color(0.85, 0.75, 0.6)
	sm.ground_bottom_color = Color(0.6, 0.62, 0.65)
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
	sun.shadow_enabled = bool(p["sun_shadows"])
	var music: String = p["music"]
	if music != "":
		AudioManager.play_music(music, 3.0)
	AudioManager.play_ambience(String(p["ambience"]))
	AudioManager.set_reverb(float(p["reverb"]))
	preset_changed.emit(preset)
