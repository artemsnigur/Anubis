class_name Lever
extends Interactable
## Pull lever that opens a gate (the shortcut). Persists through a GameState flag.

@export var flag: StringName = &"shortcut_open"
var gate: Gate
var pulled: bool = false
var _handle: Node3D


func _interactable_ready() -> void:
	prompt = "Pull the lever"
	var body := StaticBody3D.new()
	body.collision_layer = CombatTypes.LAYER_WORLD
	add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.9, 1.0, 0.9)
	cs.shape = bs
	cs.position = Vector3(0, 0.5, 0)
	body.add_child(cs)
	Kit.mesh(body, PlaceholderRig.box(Vector3(1.0, 0.9, 0.9)), Mats.get_mat(&"basalt_glyph"), Vector3(0, 0.45, 0))
	Kit.mesh(body, PlaceholderRig.box(Vector3(1.1, 0.1, 1.0)), Mats.get_mat(&"gold_world"), Vector3(0, 0.92, 0))
	_handle = Node3D.new()
	_handle.position = Vector3(0, 0.95, 0)
	_handle.rotation_degrees = Vector3(-40, 0, 0)
	add_child(_handle)
	Kit.mesh(_handle, PlaceholderRig.cylinder(0.05, 0.06, 1.1, 8), Mats.get_mat(&"bronze"), Vector3(0, 0.55, 0))
	Kit.mesh(_handle, PlaceholderRig.sphere(0.12), Mats.get_mat(&"gold"), Vector3(0, 1.1, 0))


func set_pulled(value: bool) -> void:
	pulled = value
	_handle.rotation_degrees = Vector3(40 if pulled else -40, 0, 0)


func can_interact(player: Player) -> bool:
	return not pulled and player.fsm.is_in(&"Move")


func interact(player: Player) -> void:
	var face := global_position - player.global_position
	face.y = 0.0
	player.fsm.transition_to(&"Busy", {"anim": &"interact", "duration": 0.8, "face": face, "on_event": _pull})


func _pull() -> void:
	if pulled:
		return
	pulled = true
	create_tween().tween_property(_handle, "rotation_degrees:x", 40.0, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	AudioManager.play_event(&"lever", global_position)
	GameState.set_flag(flag, true)
	if gate != null:
		gate.open()
	var lv := level()
	if lv != null:
		lv.hud.notify("A shortcut has opened", UIStyle.GOLD)
	SaveSystem.save_game()
	var p := get_tree().get_first_node_in_group(&"player") as Player
	if p != null:
		p.refresh_interactable()
