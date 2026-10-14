extends Node3D
## Test arena for movement / camera / combat feel: open floor, pillars to test the
## dithered occlusion, stairs to a platform, training dummies.

const PLAYER_SCENE := preload("res://scenes/player/player.tscn")
const DUMMY_SCENE_PATH := "res://scenes/enemies/training_dummy.tscn"

@export var spawn_dummies: bool = true

var player: Player
var camera: GameCamera
var atmosphere: Atmosphere
var nav_region: NavigationRegion3D


func _ready() -> void:
	atmosphere = Atmosphere.new()
	add_child(atmosphere)
	nav_region = NavigationRegion3D.new()
	add_child(nav_region)
	_build_geometry(nav_region)
	NavBaker.bake(nav_region)
	camera = GameCamera.new()
	add_child(camera)
	player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.teleport_to(Vector3(0, 0.1, 6), 0.0)
	camera.target = player
	camera.snap_to_target()
	if spawn_dummies and ResourceLoader.exists(DUMMY_SCENE_PATH):
		var dummy_scene := load(DUMMY_SCENE_PATH) as PackedScene
		for p: Vector3 in [Vector3(0, 0, 0), Vector3(-3, 0, -2), Vector3(3, 0, -2)]:
			var d := dummy_scene.instantiate() as Node3D
			add_child(d)
			d.global_position = p
	Vfx.prewarm()


func _build_geometry(root: Node3D) -> void:
	Kit.floor_rect(root, Rect2(-20, -20, 40, 40), 0.0, Mats.get_mat(&"sandstone_floor"))
	var wm := Mats.get_mat(&"sandstone_glyph")
	Kit.wall(root, Vector3(-20, 0, -20), Vector3(20, 0, -20), 4.0, 1.0, wm)
	Kit.wall(root, Vector3(-20, 0, 20), Vector3(20, 0, 20), 4.0, 1.0, wm)
	Kit.wall(root, Vector3(-20, 0, -20), Vector3(-20, 0, 20), 4.0, 1.0, wm)
	Kit.wall(root, Vector3(20, 0, -20), Vector3(20, 0, 20), 4.0, 1.0, wm)
	for p: Vector3 in [Vector3(-7, 0, -7), Vector3(7, 0, -7), Vector3(-7, 0, 7), Vector3(7, 0, 7)]:
		Kit.column(root, p)
	# Short wall segment for occlusion tests.
	Kit.wall(root, Vector3(-12, 0, 10), Vector3(-4, 0, 10), 3.5, 0.8, Mats.get_mat(&"tomb_wall"))
	# Raised platform with stairs.
	Kit.box(root, Vector3(12, 0.75, -12), Vector3(8, 1.5, 8), Mats.get_mat(&"sandstone"))
	Kit.stairs(root, Vector3(12, 0, -4.5), Vector3(12, 1.5, -8), 3.0, Mats.get_mat(&"sandstone"))
	Kit.obelisk(root, Vector3(-14, 0, -14))
	Kit.statue(root, Vector3(14, 1.5, -14), 180.0)
	Kit.statue(root, Vector3(-15, 0, 4), 90.0, 1.0, true)
	Kit.brazier(root, Vector3(-4, 0, -4))
	Kit.torch(root, Vector3(0, 2.4, -19.4), Vector3(0, 0, 1))
	Kit.arch(root, Vector3(0, 0, -19.5), 0.0)
	Kit.sand_drift(root, Vector3(-10, -0.05, 14), 3.0)
