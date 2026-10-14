extends PlayerState
## Generic non-combat action: pulling a lever, resting at an altar, picking up a reward.
## msg: {"anim": StringName, "duration": float (<0 = until end_busy()), "on_event": Callable, "event": StringName}

var _duration: float = 0.8
var _callback: Callable
var _event: StringName = &""
var _fired: bool = false
var _anim: StringName = &"interact"


func enter(msg: Dictionary) -> void:
	_anim = msg.get("anim", &"interact")
	_duration = float(msg.get("duration", 0.8))
	_callback = msg.get("on_event", Callable())
	_event = msg.get("event", &"interact_point")
	_fired = false
	player.animator.play(_anim, true)
	player.move_velocity = Vector3.ZERO
	player.lock_on.release()
	var face: Variant = msg.get("face")
	if face is Vector3:
		player.face_instant(face as Vector3)


func physics_update(dt: float) -> void:
	player.move_velocity = player.move_velocity.move_toward(Vector3.ZERO, 40.0 * dt)
	if not _fired and _duration > 0.0 and time_in_state >= _duration * 0.6:
		_fire()
	if _duration > 0.0 and time_in_state >= _duration:
		transition(&"Move")


func on_anim_event(event: StringName, tag: StringName) -> void:
	if tag == _anim and event == _event:
		_fire()


func _fire() -> void:
	if _fired:
		return
	_fired = true
	if _callback.is_valid():
		_callback.call()


func end_busy() -> void:
	transition(&"Move")
