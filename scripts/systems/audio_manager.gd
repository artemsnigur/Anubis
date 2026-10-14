extends Node
## Audio service: Master / Music / SFX buses, pooled positional SFX, music crossfade
## and a single event table — every combat event goes through play_event().
##
## Sounds are loaded from res://assets/audio/. Variants share a base name with a
## numeric suffix (step_sand_1.wav, step_sand_2.wav ...) and are picked at random.

const AUDIO_DIR := "res://assets/audio/"
const POOL_3D := 32
const POOL_2D := 8

## event -> [sound base name, volume dB, min pitch, max pitch]
const EVENTS: Dictionary = {
	&"light_swing": ["whoosh_light", -6.0, 0.92, 1.12],
	&"heavy_swing": ["whoosh_heavy", -3.0, 0.9, 1.05],
	&"enemy_swing": ["whoosh_heavy", -5.0, 0.75, 0.9],
	&"hit_enemy": ["hit_flesh", -2.0, 0.9, 1.1],
	&"hit_heavy": ["hit_heavy", 0.0, 0.9, 1.05],
	&"hit_stone": ["hit_stone", -3.0, 0.9, 1.1],
	&"player_hurt": ["faience_crack", -1.0, 0.95, 1.08],
	&"dodge": ["dodge_roll", -5.0, 0.95, 1.1],
	&"footstep_sand": ["step_sand", -15.0, 0.85, 1.15],
	&"footstep_stone": ["step_stone", -14.0, 0.85, 1.15],
	&"charge_ready": ["charge_ready", -4.0, 1.0, 1.0],
	&"ra_cast": ["ra_cast", -3.0, 0.95, 1.05],
	&"ra_impact": ["ra_impact", -2.0, 0.9, 1.1],
	&"no_energy": ["ui_deny", -6.0, 1.0, 1.0],
	&"heal": ["ankh_heal", -2.0, 1.0, 1.0],
	&"heal_start": ["heal_start", -6.0, 1.0, 1.0],
	&"ka_pickup": ["ka_chime", -9.0, 0.9, 1.25],
	&"heart_pickup": ["heart_recover", -1.0, 1.0, 1.0],
	&"level_up": ["level_up", -2.0, 1.0, 1.0],
	&"altar_rest": ["altar_rest", -2.0, 1.0, 1.0],
	&"altar_kindle": ["altar_kindle", -2.0, 1.0, 1.0],
	&"player_death": ["death_drone", 0.0, 1.0, 1.0],
	&"telegraph": ["glint", -4.0, 0.95, 1.05],
	&"telegraph_heavy": ["warn_low", -2.0, 0.95, 1.05],
	&"stagger": ["poise_break", 0.0, 0.95, 1.05],
	&"enemy_death": ["enemy_death", -3.0, 0.85, 1.1],
	&"mummy_groan": ["mummy_groan", -4.0, 0.85, 1.05],
	&"scarab_chitter": ["scarab_chitter", -9.0, 0.9, 1.3],
	&"jackal_growl": ["jackal_growl", -4.0, 0.9, 1.1],
	&"cobra_hiss": ["cobra_hiss", -4.0, 0.9, 1.1],
	&"spit": ["spit", -3.0, 0.9, 1.1],
	&"puddle": ["puddle_sizzle", -8.0, 0.9, 1.1],
	&"ammit_roar": ["ammit_roar", 2.0, 0.95, 1.0],
	&"ammit_snap": ["ammit_snap", 0.0, 0.9, 1.05],
	&"shockwave": ["shockwave", 1.0, 0.95, 1.05],
	&"burrow": ["burrow", -1.0, 0.95, 1.05],
	&"erupt": ["erupt", 1.0, 0.95, 1.05],
	&"gate_open": ["gate_grind", -2.0, 0.95, 1.0],
	&"lever": ["lever_clunk", -2.0, 1.0, 1.0],
	&"spike_click": ["spike_click", -4.0, 1.0, 1.0],
	&"spikes": ["spikes_out", -2.0, 0.95, 1.05],
	&"veil": ["sand_veil", -2.0, 1.0, 1.0],
	&"reward": ["reward", -1.0, 1.0, 1.0],
	&"victory": ["victory", 0.0, 1.0, 1.0],
	&"ui_click": ["ui_click", -8.0, 1.0, 1.0],
	&"ui_move": ["ui_move", -12.0, 1.0, 1.0],
	&"ui_deny": ["ui_deny", -8.0, 1.0, 1.0],
}

var _library: Dictionary = {}   # base name -> Array[AudioStream]
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _pool_2d: Array[AudioStreamPlayer] = []
var _next_3d: int = 0
var _next_2d: int = 0
var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _music_current: AudioStreamPlayer
var _music_name: String = ""
var _ambience: AudioStreamPlayer
var _ambience_name: String = ""
var _reverb: AudioEffectReverb
var _event_cooldowns: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_buses()
	_load_library()
	for i in POOL_3D:
		var p := AudioStreamPlayer3D.new()
		p.bus = &"SFX"
		p.unit_size = 7.0
		p.max_distance = 45.0
		p.attenuation_filter_cutoff_hz = 9000.0
		p.max_polyphony = 1
		add_child(p)
		_pool_3d.append(p)
	for i in POOL_2D:
		var p2 := AudioStreamPlayer.new()
		p2.bus = &"SFX"
		add_child(p2)
		_pool_2d.append(p2)
	_music_a = _make_music_player()
	_music_b = _make_music_player()
	_music_current = _music_a
	_ambience = _make_music_player()
	_ambience.bus = &"SFX"
	Settings.apply()


func _setup_buses() -> void:
	for bus_name: StringName in [&"Music", &"SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			var idx := AudioServer.bus_count - 1
			AudioServer.set_bus_name(idx, bus_name)
			AudioServer.set_bus_send(idx, &"Master")
	var sfx_idx := AudioServer.get_bus_index(&"SFX")
	if AudioServer.get_bus_effect_count(sfx_idx) == 0:
		_reverb = AudioEffectReverb.new()
		_reverb.room_size = 0.55
		_reverb.damping = 0.6
		_reverb.wet = 0.08
		_reverb.dry = 1.0
		AudioServer.add_bus_effect(sfx_idx, _reverb)
	var master_idx := AudioServer.get_bus_index(&"Master")
	if AudioServer.get_bus_effect_count(master_idx) == 0:
		var limiter := AudioEffectHardLimiter.new()
		limiter.ceiling_db = -0.5
		AudioServer.add_bus_effect(master_idx, limiter)


func _make_music_player() -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = &"Music"
	p.volume_db = -80.0
	add_child(p)
	return p


func _load_library() -> void:
	var dir := DirAccess.open(AUDIO_DIR)
	if dir == null:
		return
	for file_name in dir.get_files():
		var fname := file_name.trim_suffix(".import").trim_suffix(".remap")
		if not fname.ends_with(".wav"):
			continue
		var stream := load(AUDIO_DIR + fname) as AudioStream
		if stream == null:
			continue
		var base := fname.get_basename()
		var parts := base.rsplit("_", true, 1)
		if parts.size() == 2 and parts[1].is_valid_int():
			base = parts[0]
		if not _library.has(base):
			_library[base] = []
		var list: Array = _library[base]
		if not list.has(stream):
			list.append(stream)


func has_sound(sound: String) -> bool:
	return _library.has(sound)


func _pick(sound: String) -> AudioStream:
	var list: Array = _library.get(sound, [])
	if list.is_empty():
		return null
	return list[randi() % list.size()] as AudioStream


## Plays a named combat/UI event. `pos` = Vector3 for positional audio, null for 2D.
func play_event(event: StringName, pos: Variant = null, volume_offset: float = 0.0) -> void:
	if not EVENTS.has(event):
		return
	# Avoid machine-gun stacking of the same event within one physics frame.
	var now := Time.get_ticks_msec()
	if int(_event_cooldowns.get(event, 0)) > now:
		return
	_event_cooldowns[event] = now + 25
	var e: Array = EVENTS[event]
	play(String(e[0]), pos, float(e[1]) + volume_offset, randf_range(float(e[2]), float(e[3])))


func play(sound: String, pos: Variant = null, volume_db: float = 0.0, pitch: float = 1.0) -> void:
	var stream := _pick(sound)
	if stream == null:
		return
	if pos is Vector3:
		var p := _pool_3d[_next_3d]
		_next_3d = (_next_3d + 1) % _pool_3d.size()
		p.stop()
		p.global_position = pos
		p.stream = stream
		p.volume_db = volume_db
		p.pitch_scale = pitch
		p.play()
	else:
		var p2 := _pool_2d[_next_2d]
		_next_2d = (_next_2d + 1) % _pool_2d.size()
		p2.stop()
		p2.stream = stream
		p2.volume_db = volume_db
		p2.pitch_scale = pitch
		p2.play()


func play_music(track: String, fade_time: float = 2.0) -> void:
	if track == _music_name:
		return
	_music_name = track
	var old := _music_current
	var next := _music_b if _music_current == _music_a else _music_a
	_music_current = next
	var tw := create_tween().set_parallel(true)
	if old.playing:
		tw.tween_property(old, "volume_db", -80.0, fade_time)
	var stream := _pick(track)
	if stream != null:
		_make_looping(stream)
		next.stream = stream
		next.volume_db = -40.0
		next.play()
		tw.tween_property(next, "volume_db", 0.0, fade_time)
	tw.chain().tween_callback(old.stop)


func stop_music(fade_time: float = 2.0) -> void:
	_music_name = ""
	var p := _music_current
	var tw := create_tween()
	tw.tween_property(p, "volume_db", -80.0, fade_time)
	tw.tween_callback(p.stop)


func play_ambience(track: String, volume_db: float = -10.0) -> void:
	if track == _ambience_name:
		return
	_ambience_name = track
	var stream := _pick(track)
	if stream == null:
		_ambience.stop()
		return
	_make_looping(stream)
	_ambience.stream = stream
	_ambience.volume_db = -50.0
	_ambience.play()
	create_tween().tween_property(_ambience, "volume_db", volume_db, 2.5)


## Interior spaces get more reverb on the SFX bus.
func set_reverb(wet: float, room_size: float = 0.55) -> void:
	if _reverb == null:
		return
	var tw := create_tween().set_parallel(true)
	tw.tween_property(_reverb, "wet", wet, 1.5)
	tw.tween_property(_reverb, "room_size", room_size, 1.5)


func _make_looping(stream: AudioStream) -> void:
	if stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * float(wav.mix_rate))
