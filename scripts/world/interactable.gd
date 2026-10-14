class_name Interactable
extends Area3D
## Something the player can use with the interact action (altars, levers, chests).

@export var prompt: String = "Interact"
@export var radius: float = 1.4


func _ready() -> void:
	collision_layer = CombatTypes.LAYER_INTERACT
	collision_mask = 0
	monitoring = false
	monitorable = true
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = radius
	cs.shape = s
	cs.position = Vector3.UP * 0.8
	add_child(cs)
	_interactable_ready()


func _interactable_ready() -> void:
	return


func can_interact(_player: Player) -> bool:
	return true


func get_prompt() -> String:
	return prompt


func interact(_player: Player) -> void:
	return


func level() -> Level:
	return get_tree().get_first_node_in_group(&"level") as Level
