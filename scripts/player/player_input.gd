class_name PlayerInput
extends Node
## Reads the Input Map for the player, buffers action presses (FeelPreset.buffer_time)
## and resolves aiming for mouse (cursor projected onto the floor plane) and gamepad
## (right stick). The Player calls poll() first thing in its own physics tick, so a press
## reaches the state machine in the tick it arrives - no frame of delay. Buffered presses
## age in the hero's local time (frozen during hitstop) when the preset says so.
## A test bot can drive the player through the `bot_*` fields instead of real input.

const BUFFERED: Array[StringName] = [&"attack_light", &"attack_heavy", &"dodge", &"ranged", &"heal", &"interact", &"lock_on", &"target_next", &"target_prev"]
## Actions bound to mouse buttons: ignored while the cursor is over a debug panel.
const MOUSE_ACTIONS: Array[StringName] = [&"attack_light", &"attack_heavy", &"lock_on", &"target_next", &"target_prev"]
const STICK_DEADZONE := 0.2
const AIM_STICK_THRESHOLD := 0.35

var using_gamepad: bool = false
var enabled: bool = true
var camera: Camera3D

## Bot / test control.
var bot_enabled: bool = false
var bot_move: Vector2 = Vector2.ZERO
var bot_aim: Vector3 = Vector3.ZERO
var bot_held: Dictionary = {}

var _buffer: Dictionary = {}
var _last_aim: Vector3 = Vector3.ZERO
var _right_stick_was_flicked: bool = false


func _input(event: InputEvent) -> void:
	if event is InputEventJoypadButton:
		using_gamepad = true
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.4:
		using_gamepad = true
	elif event is InputEventMouseMotion and (event as InputEventMouseMotion).relative.length() > 2.0:
		using_gamepad = false
	elif event is InputEventMouseButton or event is InputEventKey:
		using_gamepad = false


func buffer_time() -> float:
	return GameState.feel.buffer_time


## Called by the Player first thing in its physics tick (before the state machine).
## `local_dt` is 0 while the hero is frozen by hitstop. Returns true when dodge was
## pressed in this tick (a dodge may cut the hero's own hitstop short).
func poll(local_dt: float, real_dt: float) -> bool:
	var age := local_dt if GameState.feel.buffer_in_local_time else real_dt
	for a: StringName in _buffer.keys():
		_buffer[a] = float(_buffer[a]) - age
		if float(_buffer[a]) <= 0.0:
			_buffer.erase(a)
	if not enabled or bot_enabled:
		return false
	var dodge := false
	var mouse_blocked: bool = not using_gamepad and DebugOverlay.ui_has_mouse()
	for a in BUFFERED:
		if Input.is_action_just_pressed(a):
			if mouse_blocked and MOUSE_ACTIONS.has(a):
				continue
			_buffer[a] = buffer_time()
			dodge = dodge or a == &"dodge"
	_detect_stick_flick()
	return dodge


## Simulates a press from a bot / test.
func bot_press(action: StringName) -> void:
	_buffer[action] = buffer_time()


func bot_hold(action: StringName, held: bool) -> void:
	bot_held[action] = held


## True if `action` was pressed within the buffer window; consumes it.
func consume(action: StringName) -> bool:
	if _buffer.has(action):
		_buffer.erase(action)
		return true
	return false


func peek(action: StringName) -> bool:
	return _buffer.has(action)


func clear_buffer() -> void:
	_buffer.clear()


func is_held(action: StringName) -> bool:
	if bot_enabled:
		return bool(bot_held.get(action, false))
	if not enabled:
		return false
	return Input.is_action_pressed(action)


## 2D move input (length 0..1), y = down on screen. Keyboard diagonals are normalised;
## the stick gets a radial deadzone (rescaled) and the preset's response curve.
func move_vector() -> Vector2:
	if bot_enabled:
		return bot_move.limit_length(1.0)
	if not enabled:
		return Vector2.ZERO
	var v := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down", 0.0)
	var l := v.length()
	if l < 0.0001:
		return Vector2.ZERO
	if l > 0.999 and not using_gamepad:
		return v / l
	var f := GameState.feel
	if l <= f.stick_deadzone:
		return Vector2.ZERO
	var m := clampf(inverse_lerp(f.stick_deadzone, 1.0, minf(l, 1.0)), 0.0, 1.0)
	return v / l * pow(m, f.stick_response_exponent)


## Camera-relative world direction scaled by input magnitude (0..1).
func move_world() -> Vector3:
	return screen_to_world(move_vector())


func screen_to_world(v: Vector2) -> Vector3:
	if v.length_squared() < 0.0001:
		return Vector3.ZERO
	var right := Vector3.RIGHT
	var fwd := Vector3.FORWARD
	if camera != null:
		right = camera.global_basis.x
		right.y = 0.0
		right = right.normalized()
		fwd = -camera.global_basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
	return right * v.x - fwd * v.y


## Aim direction from mouse cursor or right stick. ZERO when there is no aim input.
func aim_direction(origin: Vector3) -> Vector3:
	if bot_enabled:
		return bot_aim.normalized() if bot_aim.length_squared() > 0.0001 else Vector3.ZERO
	if not enabled:
		return Vector3.ZERO
	if using_gamepad:
		var s := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down", STICK_DEADZONE)
		if s.length() > AIM_STICK_THRESHOLD:
			_last_aim = screen_to_world(s).normalized()
			return _last_aim
		return Vector3.ZERO
	var p: Variant = mouse_floor_point(origin.y)
	if p == null:
		return Vector3.ZERO
	var d: Vector3 = (p as Vector3) - origin
	d.y = 0.0
	if d.length() < 0.25:
		return Vector3.ZERO
	return d.normalized()


## Mouse cursor projected onto the horizontal plane at height `y`. Null if unavailable.
func mouse_floor_point(y: float) -> Variant:
	if camera == null or not camera.is_inside_tree():
		return null
	var vp := camera.get_viewport()
	if vp == null:
		return null
	var mp := vp.get_mouse_position()
	var from := camera.project_ray_origin(mp)
	var dir := camera.project_ray_normal(mp)
	var plane := Plane(Vector3.UP, y)
	return plane.intersects_ray(from, dir)


func _detect_stick_flick() -> void:
	# A flick of the right stick (while locked on) switches targets.
	var s := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down", STICK_DEADZONE)
	if s.length() > 0.8 and not _right_stick_was_flicked:
		_right_stick_was_flicked = true
		_buffer[&"stick_flick"] = buffer_time()
		_buffer[&"stick_flick_dir"] = buffer_time()
		set_meta(&"flick", s)
	elif s.length() < 0.3:
		_right_stick_was_flicked = false


## Returns the last flick direction (screen space) and consumes it, or Vector2.ZERO.
func consume_flick() -> Vector2:
	if consume(&"stick_flick"):
		_buffer.erase(&"stick_flick_dir")
		return get_meta(&"flick", Vector2.ZERO)
	return Vector2.ZERO
