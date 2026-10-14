extends Node
## User settings (volumes, camera shake, fullscreen, feel preset). Stored in user://settings.cfg.

signal changed

const PATH := "user://settings.cfg"

var master_volume: float = 0.9
var music_volume: float = 0.6
var sfx_volume: float = 0.85
var shake_strength: float = 1.0
var fullscreen: bool = false
var camera_orthographic: bool = false
## Id of the active FeelPreset (resources/feel/<id>.tres), cycled with F7.
var feel_preset: String = "snappy"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) == OK:
		master_volume = float(cfg.get_value("audio", "master", master_volume))
		music_volume = float(cfg.get_value("audio", "music", music_volume))
		sfx_volume = float(cfg.get_value("audio", "sfx", sfx_volume))
		shake_strength = float(cfg.get_value("camera", "shake", shake_strength))
		fullscreen = bool(cfg.get_value("display", "fullscreen", fullscreen))
		camera_orthographic = bool(cfg.get_value("camera", "orthographic", camera_orthographic))
		feel_preset = String(cfg.get_value("gameplay", "feel_preset", feel_preset))
	apply()


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.set_value("audio", "sfx", sfx_volume)
	cfg.set_value("camera", "shake", shake_strength)
	cfg.set_value("display", "fullscreen", fullscreen)
	cfg.set_value("camera", "orthographic", camera_orthographic)
	cfg.set_value("gameplay", "feel_preset", feel_preset)
	cfg.save(PATH)


func apply() -> void:
	_set_bus_volume(&"Master", master_volume)
	_set_bus_volume(&"Music", music_volume)
	_set_bus_volume(&"SFX", sfx_volume)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
		if DisplayServer.window_get_mode() != mode:
			DisplayServer.window_set_mode(mode)
	changed.emit()


func set_value(key: StringName, value: Variant) -> void:
	match key:
		&"master_volume": master_volume = float(value)
		&"music_volume": music_volume = float(value)
		&"sfx_volume": sfx_volume = float(value)
		&"shake_strength": shake_strength = float(value)
		&"fullscreen": fullscreen = bool(value)
		&"camera_orthographic": camera_orthographic = bool(value)
	apply()
	save_settings()


func _set_bus_volume(bus_name: StringName, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx < 0:
		return
	AudioServer.set_bus_volume_db(idx, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(idx, linear <= 0.001)
