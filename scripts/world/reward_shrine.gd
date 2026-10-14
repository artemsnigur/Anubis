class_name RewardShrine
extends Interactable
## Gilded canopic shrine holding a blessing: +1 permanent Ankh charge.

@export var reward_id: StringName = &"reward_ankh"
var _lid: Node3D
var _glow: OmniLight3D
var collected: bool = false


func _interactable_ready() -> void:
	prompt = "Open the canopic shrine"
	var body := StaticBody3D.new()
	body.collision_layer = CombatTypes.LAYER_WORLD
	add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.2, 1.1, 0.9)
	cs.shape = bs
	cs.position = Vector3(0, 0.55, 0)
	body.add_child(cs)
	Kit.mesh(body, PlaceholderRig.box(Vector3(1.3, 0.2, 1.0)), Mats.get_mat(&"basalt"), Vector3(0, 0.1, 0))
	Kit.mesh(body, PlaceholderRig.box(Vector3(1.1, 0.8, 0.8)), Mats.get_mat(&"gold_world"), Vector3(0, 0.6, 0))
	Kit.mesh(body, PlaceholderRig.box(Vector3(1.12, 0.12, 0.82)), Mats.get_mat(&"lapis"), Vector3(0, 0.45, 0))
	Kit.mesh(body, PlaceholderRig.box(Vector3(0.3, 0.42, 0.02)), Mats.get_mat(&"lapis"), Vector3(0, 0.68, -0.41))
	_lid = Node3D.new()
	_lid.position = Vector3(0, 1.0, 0.4)
	add_child(_lid)
	Kit.mesh(_lid, PlaceholderRig.box(Vector3(1.2, 0.18, 0.9)), Mats.get_mat(&"gold_world"), Vector3(0, 0.09, -0.4))
	Kit.mesh(_lid, PlaceholderRig.prism(Vector3(1.0, 0.3, 0.7)), Mats.get_mat(&"lapis"), Vector3(0, 0.33, -0.4))
	_glow = OmniLight3D.new()
	_glow.light_color = Color(0.4, 1.0, 0.85)
	_glow.light_energy = 1.2
	_glow.omni_range = 4.0
	_glow.position = Vector3(0, 1.4, 0)
	add_child(_glow)
	if GameState.is_collected(reward_id):
		_set_opened(true)


func _set_opened(instant: bool) -> void:
	collected = true
	_glow.light_energy = 0.0
	if instant:
		_lid.rotation_degrees.x = -110.0
	else:
		create_tween().tween_property(_lid, "rotation_degrees:x", -110.0, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func can_interact(player: Player) -> bool:
	return not collected and player.fsm.is_in(&"Move")


func interact(player: Player) -> void:
	var face := global_position - player.global_position
	face.y = 0.0
	player.fsm.transition_to(&"Busy", {"anim": &"interact", "duration": 0.8, "face": face, "on_event": _grant.bind(player)})


func _grant(player: Player) -> void:
	if collected:
		return
	_set_opened(false)
	GameState.mark_collected(reward_id)
	GameState.bonus_ankh += 1
	player.ankh += 1
	player.resources_changed.emit()
	AudioManager.play_event(&"reward", global_position)
	Vfx.motes(global_position + Vector3.UP * 1.2, 40)
	Vfx.ring(global_position, 0.4, 4.0, 0.8, Color(0.4, 1.0, 0.85))
	Vfx.light_flash(global_position + Vector3.UP * 1.5, Color(0.5, 1.0, 0.9), 6.0, 8.0, 0.8)
	var lv := level()
	if lv != null:
		lv.hud.show_banner("Blessing of the Ankh", "+1 Ankh charge", 2.0)
	SaveSystem.save_game()
	player.refresh_interactable()
