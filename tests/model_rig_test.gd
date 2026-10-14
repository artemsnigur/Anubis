extends Node
## Verifies the asset-swap path: a fake "imported" humanoid model (Skeleton3D with
## SkeletonProfileHumanoid bone names + an AnimationPlayer with Mixamo-style clip names)
## replaces the placeholder hero through ModelRig + AnimationMap, and combat still works
## with events injected from AttackData into the imported clips.
## godot --headless res://tests/model_rig_test.tscn

const BONES := [["Hips", -1, Vector3(0, 1.0, 0)], ["Spine", 0, Vector3(0, 0.15, 0)], ["Chest", 1, Vector3(0, 0.25, 0)],
	["Head", 2, Vector3(0, 0.35, 0)], ["RightUpperArm", 2, Vector3(0.2, 0.2, 0)], ["RightLowerArm", 4, Vector3(0, -0.3, 0)],
	["RightHand", 5, Vector3(0, -0.28, 0)], ["LeftUpperArm", 2, Vector3(-0.2, 0.2, 0)], ["LeftHand", 7, Vector3(0, -0.55, 0)]]

var arena: Level
var player: Player
var _failures: int = 0
var _events: Array = []


func _ready() -> void:
	get_tree().create_timer(60.0, true, false, true).timeout.connect(func() -> void:
		print("model_rig_test: TIMEOUT")
		get_tree().quit(2))
	arena = (load("res://scenes/levels/test_arena.tscn") as PackedScene).instantiate() as Level
	arena.set("spawn_dummies", true)
	# Swap the hero's rig before the player enters the tree: replace the level's player scene.
	add_child(arena)
	player = arena.player
	_run.call_deferred()


func _fake_model() -> PackedScene:
	var root := Node3D.new()
	root.name = "FakeImportedHero"
	var skel := Skeleton3D.new()
	skel.name = "Skeleton3D"
	root.add_child(skel)
	skel.owner = root
	for b: Array in BONES:
		var i := skel.add_bone(b[0])
		skel.set_bone_parent(i, int(b[1]))
		skel.set_bone_rest(i, Transform3D(Basis.IDENTITY, b[2]))
	var mesh := MeshInstance3D.new()
	mesh.mesh = BoxMesh.new()
	skel.add_child(mesh)
	mesh.owner = root
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	ap.owner = root
	var lib := AnimationLibrary.new()
	for spec: Array in [["Idle", 1.0], ["Run", 0.7], ["Slash", 0.6], ["Roll", 0.5], ["Hit", 0.4], ["Die", 1.2]]:
		var a := Animation.new()
		a.length = float(spec[1])
		var t := a.add_track(Animation.TYPE_ROTATION_3D)
		a.track_set_path(t, NodePath("Skeleton3D:Spine"))
		a.rotation_track_insert_key(t, 0.0, Quaternion.IDENTITY)
		a.rotation_track_insert_key(t, a.length * 0.5, Quaternion(Vector3.UP, 0.5))
		lib.add_animation(StringName(spec[0]), a)
	ap.add_animation_library(&"", lib)
	var ps := PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


func _check(cond: bool, msg: String) -> void:
	print(("PASS " if cond else "FAIL ") + msg)
	if not cond:
		_failures += 1


func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout


func _run() -> void:
	# Build a second player whose rig is a ModelRig driving the fake imported model.
	var scene := load("res://scenes/player/player.tscn") as PackedScene
	var p2 := scene.instantiate() as Player
	var old_rig := p2.get_node("Visual/Rig")
	var visual := p2.get_node("Visual")
	visual.remove_child(old_rig)
	old_rig.free()
	var rig := ModelRig.new()
	rig.name = "Rig"
	rig.model_scene = _fake_model()
	var map := AnimationMap.new()
	map.clips = {&"idle": &"Idle", &"walk": &"Run", &"run": &"Run", &"light_1": &"Slash", &"light_2": &"Slash", &"light_3": &"Slash",
		&"heavy_windup": &"Slash", &"heavy_charge": &"Idle", &"heavy_release": &"Slash", &"dodge": &"Roll", &"hit": &"Hit",
		&"hit_heavy": &"Hit", &"death": &"Die", &"heal": &"Idle", &"cast": &"Slash", &"rest": &"Idle", &"grabbed": &"Hit", &"interact": &"Slash"}
	map.states.assign((load("res://resources/animation/hero_anim_map.tres") as AnimationMap).states)
	map.looping.assign([&"idle", &"walk", &"run", &"heavy_charge"])
	rig.anim_map = map
	visual.add_child(rig)
	rig.owner = p2
	# Replace the arena's player.
	player.queue_free()
	arena.add_child(p2)
	arena.player = p2
	arena.camera.target = p2
	p2.teleport_to(Vector3(0, 0.1, 1.9), 0.0)
	p2.input.bot_enabled = true
	p2.input.bot_aim = Vector3.FORWARD
	p2.animator.anim_event.connect(func(ev: StringName, tag: StringName) -> void: _events.append([ev, tag]))
	await _wait(0.6)
	_check(rig.skeleton != null and rig.has_socket(&"weapon_r"), "ModelRig found the skeleton and attached sockets to humanoid bones")
	_check(p2.animator.has_state(&"light_1") and p2.animator.has_state(&"dodge"), "AnimationTree built from the imported clips")
	var dummy: EnemyBase = null
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var c := e as EnemyBase
		if c != null and c.global_position.distance_to(Vector3.ZERO) < 0.5:
			dummy = c
	var hp0 := dummy.health.current
	p2.input.bot_press(&"attack_light")
	await _wait(0.22)
	p2.input.bot_press(&"attack_light")
	await _wait(0.7)
	var got_on := false
	var got_on_2 := false
	for e: Array in _events:
		if e[0] == &"hitbox_on" and e[1] == &"light_1":
			got_on = true
		if e[0] == &"hitbox_on" and e[1] == &"light_2":
			got_on_2 = true
	_check(got_on, "injected method track fires hitbox_on for light_1")
	_check(got_on_2, "shared clip copy fires hitbox_on tagged light_2")
	_check(dummy.health.current < hp0, "attacks through the imported rig damage the dummy (%.0f -> %.0f)" % [hp0, dummy.health.current])
	p2.input.bot_press(&"dodge")
	await _wait(0.5)
	_check(_events.any(func(e: Array) -> bool: return e[0] == &"dodge_start"), "dodge clip events injected")
	print("model_rig_test: %d failures" % _failures)
	get_tree().quit(1 if _failures > 0 else 0)
