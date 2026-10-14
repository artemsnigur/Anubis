extends Node
## Camera-shake service: forwards trauma to the active GameCamera.
## Trauma (0..1) decays over time; shake strength = trauma^2 * user setting.

var camera: Node = null


func register_camera(cam: Node) -> void:
	camera = cam


func unregister_camera(cam: Node) -> void:
	if camera == cam:
		camera = null


func add_trauma(amount: float) -> void:
	if camera != null and is_instance_valid(camera):
		camera.call(&"add_trauma", amount)


## Adds trauma scaled by distance from the camera's focus (for far explosions).
func add_trauma_at(amount: float, world_pos: Vector3, falloff: float = 18.0) -> void:
	if camera == null or not is_instance_valid(camera):
		return
	var focus: Vector3 = camera.call(&"get_focus_position")
	var k := clampf(1.0 - focus.distance_to(world_pos) / falloff, 0.0, 1.0)
	if k > 0.0:
		camera.call(&"add_trauma", amount * k)
