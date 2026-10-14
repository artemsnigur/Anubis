class_name Level
extends Node3D
## Base of a playable level: builds the world, bakes navigation, spawns the player,
## camera and UI, and runs the souls-like loop (death -> heart -> respawn at the last
## altar, rest -> restore + respawn enemies + level up + save).

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const TITLE_SCENE := "res://scenes/ui/title_menu.tscn"

@export var level_name: String = "The Necropolis"
@export var start_position: Vector3 = Vector3.ZERO
@export var start_yaw: float = 0.0
@export var initial_atmosphere: StringName = &"courtyard"

var player: Player
var camera: GameCamera
var atmosphere: Atmosphere
var nav_region: NavigationRegion3D
var enemies_root: Node3D
var hud: HUD
var fader: Fader
var death_screen: DeathScreen
var levelup: LevelUpMenu
var pause_menu: PauseMenu
var screen_fx: ScreenFX
var altars: Dictionary = {}
var _heart: KaHeart
var _busy: bool = false


func _ready() -> void:
	add_to_group(&"level")
	HitStop.reset()
	RenderingServer.global_shader_parameter_set(&"occlusion_enabled", 1.0)
	get_tree().paused = false
	atmosphere = Atmosphere.new()
	atmosphere.initial_preset = initial_atmosphere
	add_child(atmosphere)
	nav_region = NavigationRegion3D.new()
	nav_region.name = "Navigation"
	add_child(nav_region)
	enemies_root = Node3D.new()
	enemies_root.name = "Enemies"
	add_child(enemies_root)
	_build_world()
	_apply_persistent_state()
	NavBaker.bake(nav_region)
	for a in get_tree().get_nodes_in_group(&"altars"):
		var altar := a as Altar
		altars[altar.altar_id] = altar
	camera = GameCamera.new()
	camera.name = "GameCamera"
	add_child(camera)
	player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	_build_ui()
	hud.bind_player(player)
	screen_fx.bind_player(player)
	var sp := _spawn_transform()
	player.teleport_to(sp[0], sp[1])
	camera.target = player
	camera.snap_to_target()
	for s in get_tree().get_nodes_in_group(&"spawners"):
		var sp2 := s as EnemySpawner
		if not sp2.deferred:
			sp2.spawn(enemies_root)
	_spawn_heart()
	player.death_finished.connect(_on_player_death_finished)
	pause_menu.quit_to_title.connect(_quit_to_title)
	Vfx.prewarm()
	_level_started.call_deferred()


## Subclass: create geometry under nav_region and props/altars/spawners under self.
func _build_world() -> void:
	return


## Subclass: re-apply saved world flags (open gates, collected rewards, boss).
func _apply_persistent_state() -> void:
	return


## Subclass: called after enemies were respawned (traps, boss arena ...).
func _on_world_reset() -> void:
	return


func _level_started() -> void:
	fader.fade_in(1.2)
	if GameState.last_altar == &"":
		hud.show_banner(level_name, "Heart of the Duat")


func _build_ui() -> void:
	screen_fx = ScreenFX.new()
	add_child(screen_fx)
	hud = HUD.new()
	add_child(hud)
	death_screen = DeathScreen.new()
	add_child(death_screen)
	levelup = LevelUpMenu.new()
	add_child(levelup)
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	fader = Fader.new()
	add_child(fader)
	fader.set_black()


## [position, yaw] where the player appears (pending / last altar, or the level start).
func _spawn_transform() -> Array:
	var id := GameState.pending_spawn_altar if GameState.pending_spawn_altar != &"" else GameState.last_altar
	GameState.pending_spawn_altar = &""
	if id != &"" and altars.has(id):
		var a := altars[id] as Altar
		return [a.spawn_point(), a.spawn_yaw()]
	return [start_position, start_yaw]


func _spawn_heart() -> void:
	if _heart != null and is_instance_valid(_heart):
		_heart.queue_free()
	_heart = null
	if GameState.has_heart:
		_heart = KaHeart.new()
		add_child(_heart)
		_heart.global_position = GameState.heart_position
		_heart.reset_physics_interpolation()


## Gates / veils changed: rebuild the navmesh in the background.
func rebake_navigation() -> void:
	NavBaker.rebake_async(nav_region)


## Respawns every enemy, clears hazards and resets level mechanisms.
func reset_world() -> void:
	for s in get_tree().get_nodes_in_group(&"spawners"):
		(s as EnemySpawner).respawn(enemies_root)
	for t in get_tree().get_nodes_in_group(&"transient"):
		t.queue_free()
	_on_world_reset()


# --- death ------------------------------------------------------------------------

func _on_player_death_finished() -> void:
	if _busy:
		return
	_busy = true
	var had_heart := GameState.has_heart
	var carried := GameState.ka
	GameState.drop_heart(player.last_safe_position)
	SaveSystem.save_game()
	pause_menu.allowed = false
	hud.set_visible_hud(false)
	death_screen.show_death(carried, had_heart)
	await death_screen.finished
	await fader.fade_out(0.8)
	death_screen.hide_screen()
	respawn_player()
	hud.set_visible_hud(true)
	await fader.fade_in(1.0)
	pause_menu.allowed = true
	_busy = false


func respawn_player() -> void:
	HitStop.reset()
	reset_world()
	var sp := _spawn_transform()
	player.respawn_at(sp[0], sp[1])
	camera.snap_to_target()
	_spawn_heart()


# --- resting ----------------------------------------------------------------------

func rest_at(altar: Altar, p: Player) -> void:
	if _busy:
		return
	_busy = true
	pause_menu.allowed = false
	var face := altar.global_position - p.global_position
	face.y = 0.0
	p.fsm.transition_to(&"Busy", {"anim": &"rest", "duration": -1.0, "face": face})
	AudioManager.play_event(&"altar_rest", altar.global_position)
	await get_tree().create_timer(0.9).timeout
	await fader.fade_out(0.5)
	GameState.last_altar = altar.altar_id
	reset_world()
	p.refresh_stats(true)
	p.invulnerable_time = 1.0
	SaveSystem.save_game()
	await fader.fade_in(0.5)
	levelup.open()
	await levelup.closed
	if p.fsm.is_in(&"Busy"):
		p.fsm.current.call(&"end_busy")
	SaveSystem.save_game()
	pause_menu.allowed = true
	_busy = false


func _quit_to_title() -> void:
	SaveSystem.save_game()
	get_tree().paused = false
	HitStop.reset()
	get_tree().change_scene_to_file(TITLE_SCENE)
