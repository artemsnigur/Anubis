class_name Gate
extends StaticBody3D
## Bronze portcullis blocking an opening. Slides into the floor when opened.
## Lives on the "gate" physics layer (not baked into the navmesh).

signal opened

@export var gate_id: StringName = &"gate"
@export var width: float = 4.0
@export var height: float = 4.5
@export var thickness: float = 0.4

var is_open: bool = false
var _bars: Node3D
var _shape: CollisionShape3D


func _ready() -> void:
	collision_layer = CombatTypes.LAYER_GATE
	collision_mask = 0
	_shape = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, height, thickness)
	_shape.shape = bs
	_shape.position = Vector3(0, height * 0.5, 0)
	add_child(_shape)
	_bars = Node3D.new()
	add_child(_bars)
	var bronze := Mats.get_mat(&"bronze")
	var n := int(width / 0.42)
	for i in n:
		var x := -width * 0.5 + (float(i) + 0.5) * width / float(n)
		Kit.mesh(_bars, PlaceholderRig.cylinder(0.05, 0.05, height, 8), bronze, Vector3(x, height * 0.5, 0))
		Kit.mesh(_bars, PlaceholderRig.cylinder(0.0, 0.07, 0.25, 6), Mats.get_mat(&"gold"), Vector3(x, 0.05, 0), Vector3(180, 0, 0))
	for y: float in [0.6, height * 0.5, height - 0.3]:
		Kit.mesh(_bars, PlaceholderRig.box(Vector3(width, 0.14, 0.16)), bronze, Vector3(0, y, 0))
	Kit.mesh(_bars, PlaceholderRig.cylinder(0.32, 0.32, 0.06, 16), Mats.get_mat(&"gold"), Vector3(0, height * 0.5, 0.1), Vector3(90, 0, 0))


func open(instant: bool = false) -> void:
	if is_open:
		return
	is_open = true
	if instant:
		_shape.disabled = true
	else:
		_shape.set_deferred(&"disabled", true)
	if instant:
		_bars.position.y = -height + 0.15
		_bars.visible = false
	else:
		var tw := create_tween()
		tw.tween_property(_bars, "position:y", -height + 0.15, 2.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		AudioManager.play_event(&"gate_open", global_position)
		CameraShake.add_trauma_at(0.3, global_position)
		for i in 4:
			Vfx.dust(global_transform * Vector3(-width * 0.5 + width * float(i) / 3.0, 0, 0), 6, 1.2)
		get_tree().create_timer(2.3).timeout.connect(func() -> void: opened.emit())


func close(instant: bool = false) -> void:
	if not is_open:
		return
	is_open = false
	if instant:
		_shape.disabled = false
	else:
		_shape.set_deferred(&"disabled", false)
	_bars.visible = true
	if instant:
		_bars.position.y = 0.0
	else:
		create_tween().tween_property(_bars, "position:y", 0.0, 0.8).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
		AudioManager.play_event(&"gate_open", global_position)
