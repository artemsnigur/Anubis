class_name Altar
extends Interactable
## Altar of Osiris: checkpoint. First use kindles it (green flame of rebirth).
## Resting restores health and Ankh charges, respawns enemies, opens the level-up
## menu and saves. Death returns the player to the last altar used.

@export var altar_id: StringName = &"altar"
@export var display_name: String = "Altar of Osiris"

var lit: bool = false
var _flame: Node3D
var _light: OmniLight3D


func _interactable_ready() -> void:
	add_to_group(&"altars")
	radius = 1.8
	_build_visual()
	set_lit(GameState.get_flag(StringName("altar_" + String(altar_id))), true)


func _build_visual() -> void:
	var body := StaticBody3D.new()
	body.collision_layer = CombatTypes.LAYER_WORLD
	add_child(body)
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.6, 1.0, 1.0)
	cs.shape = bs
	cs.position = Vector3(0, 0.5, 0)
	body.add_child(cs)
	Kit.mesh(body, PlaceholderRig.box(Vector3(1.9, 0.25, 1.3)), Mats.get_mat(&"basalt"), Vector3(0, 0.12, 0))
	Kit.mesh(body, PlaceholderRig.box(Vector3(1.5, 0.75, 0.9)), Mats.get_mat(&"basalt_glyph"), Vector3(0, 0.62, 0))
	Kit.mesh(body, PlaceholderRig.box(Vector3(1.7, 0.12, 1.05)), Mats.get_mat(&"gold_world"), Vector3(0, 1.04, 0))
	# Djed pillar (the backbone of Osiris) behind the altar.
	Kit.mesh(body, PlaceholderRig.cylinder(0.16, 0.2, 2.2, 10), Mats.get_mat(&"turquoise_stone"), Vector3(0, 1.1, 0.75))
	for i in 4:
		Kit.mesh(body, PlaceholderRig.cylinder(0.34, 0.34, 0.08, 12), Mats.get_mat(&"gold_world"), Vector3(0, 1.75 + i * 0.13, 0.75))
	# Green bowl.
	Kit.mesh(body, PlaceholderRig.cylinder(0.32, 0.18, 0.18, 14), Mats.get_mat(&"bronze"), Vector3(0, 1.18, 0))
	_flame = Node3D.new()
	_flame.position = Vector3(0, 1.3, 0)
	add_child(_flame)
	Kit._flame(_flame, Vector3.ZERO, 1.9, &"osiris")
	_light = TorchLight.new()
	_light.light_color = Color(0.35, 1.0, 0.6)
	_light.base_energy = 2.5
	_light.omni_range = 7.0
	_light.position = Vector3(0, 1.9, 0)
	_light.light_volumetric_fog_energy = 2.0
	add_child(_light)


func set_lit(value: bool, instant: bool = false) -> void:
	lit = value
	_flame.visible = lit
	_light.base_energy = 2.5 if lit else 0.35
	_light.light_energy = _light.base_energy
	if lit and not instant:
		Vfx.motes(global_position + Vector3.UP * 1.4, 30)
		Vfx.ring(global_position, 0.5, 5.0, 0.8, Color(0.3, 1.0, 0.6))
		Vfx.light_flash(global_position + Vector3.UP * 1.5, Color(0.4, 1.0, 0.6), 6.0, 10.0, 0.8)


func spawn_point() -> Vector3:
	return global_transform * Vector3(0, 0.1, -1.7)


func spawn_yaw() -> float:
	return global_rotation.y


func get_prompt() -> String:
	return "Kindle the %s" % display_name if not lit else "Rest at the %s" % display_name


func can_interact(player: Player) -> bool:
	return not player.is_dead and player.fsm.is_in(&"Move")


func interact(player: Player) -> void:
	var lv := level()
	if lv == null:
		return
	if not lit:
		set_lit(true)
		GameState.set_flag(StringName("altar_" + String(altar_id)), true)
		AudioManager.play_event(&"altar_kindle", global_position)
		lv.hud.notify("Altar of Osiris kindled", UIStyle.TURQUOISE)
	lv.rest_at(self, player)
