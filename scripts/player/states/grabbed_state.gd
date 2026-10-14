extends PlayerState
## Held by a Mummy Guardian. The grabber positions the player and releases it.

var grabber: Node3D


func enter(msg: Dictionary) -> void:
	grabber = msg.get("grabber") as Node3D
	player.animator.play(&"grabbed", true)
	player.move_velocity = Vector3.ZERO
	player.hitbox.deactivate()
	player.trail.emitting = false
	player.input.clear_buffer()


func can_be_interrupted() -> bool:
	return false


func physics_update(_dt: float) -> void:
	player.move_velocity = Vector3.ZERO
	if grabber == null or not is_instance_valid(grabber) or time_in_state > 3.0:
		transition(&"Hurt", {"heavy": true})
		return
	var socket: Node3D = grabber.call(&"grab_socket") as Node3D
	if socket != null:
		var p := socket.global_position
		player.global_position = Vector3(p.x, maxf(p.y - 1.0, grabber.global_position.y), p.z)
		player.face_instant(player.direction_to_node(grabber))


func release(knock_dir: Vector3) -> void:
	player.apply_knockback(knock_dir, 9.0)
	transition(&"Hurt", {"heavy": true})
