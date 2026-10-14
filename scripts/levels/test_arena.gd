extends Level
## Test arena for movement / camera / combat feel and the souls-like loop:
## open floor, pillars to test the dithered occlusion, stairs to a platform,
## training dummies, an Altar of Osiris and optional enemy spawners.

const DUMMY_SCENE := preload("res://scenes/enemies/training_dummy.tscn")

@export var spawn_dummies: bool = true


func _init() -> void:
	level_name = "Test Arena"
	start_position = Vector3(0, 0.1, 6)


func _build_world() -> void:
	var root := nav_region
	Kit.floor_rect(root, Rect2(-20, -20, 40, 40), 0.0, Mats.get_mat(&"sandstone_floor"))
	var wm := Mats.get_mat(&"sandstone_glyph")
	Kit.wall(root, Vector3(-20, 0, -20), Vector3(20, 0, -20), 4.0, 1.0, wm)
	Kit.wall(root, Vector3(-20, 0, 20), Vector3(20, 0, 20), 4.0, 1.0, wm)
	Kit.wall(root, Vector3(-20, 0, -20), Vector3(-20, 0, 20), 4.0, 1.0, wm)
	Kit.wall(root, Vector3(20, 0, -20), Vector3(20, 0, 20), 4.0, 1.0, wm)
	for p: Vector3 in [Vector3(-7, 0, -7), Vector3(7, 0, -7), Vector3(-7, 0, 7), Vector3(7, 0, 7)]:
		Kit.column(root, p)
	Kit.wall(root, Vector3(-12, 0, 10), Vector3(-4, 0, 10), 3.5, 0.8, Mats.get_mat(&"tomb_wall"))
	Kit.box(root, Vector3(12, 0.75, -12), Vector3(8, 1.5, 8), Mats.get_mat(&"sandstone"))
	Kit.stairs(root, Vector3(12, 0, -4.5), Vector3(12, 1.5, -8), 3.0, Mats.get_mat(&"sandstone"))
	Kit.obelisk(root, Vector3(-14, 0, -14))
	Kit.statue(root, Vector3(14, 1.5, -14), 180.0)
	Kit.statue(root, Vector3(-15, 0, 4), 90.0, 1.0, true)
	Kit.brazier(root, Vector3(-4, 0, -4))
	Kit.torch(root, Vector3(0, 2.4, -19.4), Vector3(0, 0, 1))
	Kit.arch(root, Vector3(0, 0, -19.5), 0.0)
	Kit.sand_drift(root, Vector3(-10, -0.05, 14), 3.0)
	var altar := Altar.new()
	altar.altar_id = &"test_altar"
	add_child(altar)
	altar.position = Vector3(10, 0, 12)
	altar.rotation.y = PI
	if spawn_dummies:
		for p: Vector3 in [Vector3(0, 0, 0), Vector3(-3, 0, -2), Vector3(3, 0, -2)]:
			var s := EnemySpawner.new()
			s.enemy_scene = DUMMY_SCENE
			add_child(s)
			s.position = p
