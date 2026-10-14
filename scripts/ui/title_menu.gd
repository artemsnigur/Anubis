extends Node3D
## Title screen: the ushabti on its plinth in torchlight, menu on the left.

const LEVEL_SCENE := "res://scenes/levels/test_arena.tscn"

var _menu: VBoxContainer
var _settings: SettingsPanel
var _continue: Button
var _new: Button
var _rig: HeroRig
var _t: float = 0.0
var _starting: bool = false
var _fader: Fader


func _ready() -> void:
	get_tree().paused = false
	HitStop.reset()
	_build_scene()
	_build_ui()
	AudioManager.play_music("music_title", 2.0)
	AudioManager.play_ambience("amb_tomb", -16.0)


func _build_scene() -> void:
	RenderingServer.global_shader_parameter_set(&"occlusion_enabled", 0.0)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.015, 0.02, 0.05)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.16, 0.2, 0.38)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.glow_enabled = true
	e.glow_intensity = 0.9
	e.volumetric_fog_enabled = true
	e.volumetric_fog_density = 0.018
	e.volumetric_fog_albedo = Color(0.32, 0.36, 0.48)
	env.environment = e
	add_child(env)
	Kit.box(self, Vector3(0, -0.5, 0), Vector3(30, 1, 30), Mats.get_mat(&"tomb_floor"))
	Kit.box(self, Vector3(0, 0.4, 0), Vector3(1.8, 0.8, 1.8), Mats.get_mat(&"basalt_glyph"))
	Kit.box(self, Vector3(0, 0.85, 0), Vector3(2.0, 0.1, 2.0), Mats.get_mat(&"gold_world"))
	Kit.box(self, Vector3(0, 3.5, -7.0), Vector3(24, 7, 1), Mats.get_mat(&"tomb_wall"))
	Kit.column(self, Vector3(-3.5, 0, -2.5), 6.0)
	Kit.column(self, Vector3(3.5, 0, -2.5), 6.0)
	Kit.brazier(self, Vector3(-2.2, 0, 1.0), 2.2, 7.0, true)
	Kit.brazier(self, Vector3(2.2, 0, 1.0), 1.6, 6.0, false)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color(0.45, 0.6, 1.0)
	rim.light_energy = 0.55
	rim.rotation_degrees = Vector3(-25, 160, 0)
	add_child(rim)
	_rig = HeroRig.new()
	_rig.anim_map = load("res://resources/animation/hero_anim_map.tres")
	add_child(_rig)
	_rig.position = Vector3(0, 0.9, 0)
	_rig.rotation.y = PI + 0.35
	_rig.build({})
	_rig.get_animation_player().play(&"idle")
	var cam := Camera3D.new()
	cam.fov = 32.0
	add_child(cam)
	cam.position = Vector3(-1.6, 2.4, 6.2)
	cam.look_at(Vector3(-0.9, 1.7, 0))
	cam.make_current()


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UIStyle.theme()
	layer.add_child(root)
	var col := VBoxContainer.new()
	col.position = Vector2(140, 200)
	col.add_theme_constant_override(&"separation", 16)
	root.add_child(col)
	var t1 := UIStyle.label("HEART", 96, UIStyle.GOLD, true)
	t1.add_theme_constant_override(&"outline_size", 12)
	col.add_child(t1)
	var t2 := UIStyle.label("OF THE DUAT", 54, UIStyle.GOLD, true)
	t2.add_theme_constant_override(&"outline_size", 10)
	col.add_child(t2)
	var sub := UIStyle.label("An ushabti awakens in the underworld.", 24, UIStyle.PAPYRUS)
	col.add_child(sub)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 40)
	col.add_child(spacer)
	_menu = VBoxContainer.new()
	_menu.add_theme_constant_override(&"separation", 12)
	_menu.custom_minimum_size = Vector2(360, 0)
	col.add_child(_menu)
	_continue = UIStyle.button("Continue", _on_continue)
	_continue.visible = SaveSystem.has_save()
	_menu.add_child(_continue)
	_new = UIStyle.button("New Game", _on_new_game)
	_menu.add_child(_new)
	_menu.add_child(UIStyle.button("Settings", _on_settings))
	_menu.add_child(UIStyle.button("Quit", func() -> void: get_tree().quit()))
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(_on_settings_closed)
	col.add_child(_settings)
	var hint := UIStyle.label("Keyboard + mouse or gamepad", 18, UIStyle.GOLD_DIM)
	hint.anchor_top = 1.0
	hint.anchor_bottom = 1.0
	hint.offset_left = 140
	hint.offset_top = -70
	root.add_child(hint)
	if _continue.visible:
		_continue.grab_focus()
	else:
		_new.grab_focus()
	_fader = Fader.new()
	add_child(_fader)
	_fader.set_black()
	_fader.fade_in(1.2)


func _process(delta: float) -> void:
	_t += delta
	if _rig != null:
		_rig.rotation.y = PI + 0.35 + sin(_t * 0.3) * 0.25


func _on_continue() -> void:
	if _starting:
		return
	if SaveSystem.load_game():
		GameState.pending_spawn_altar = GameState.last_altar
	_start()


func _on_new_game() -> void:
	if _starting:
		return
	SaveSystem.delete_save()
	GameState.reset_progress()
	_start()


func _start() -> void:
	_starting = true
	AudioManager.stop_music(1.0)
	await _fader.fade_out(0.8)
	get_tree().change_scene_to_file(LEVEL_SCENE)


func _on_settings() -> void:
	_menu.visible = false
	_settings.visible = true
	_settings.focus_first()


func _on_settings_closed() -> void:
	_settings.visible = false
	_menu.visible = true
	_new.grab_focus()
