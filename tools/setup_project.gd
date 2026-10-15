extends SceneTree
## Dev tool: writes the Input Map and global shader uniforms into project.godot.
## Run: godot --headless --script res://tools/setup_project.gd
## Letting the engine serialise the InputEvent objects guarantees a valid format.

const DEADZONE := 0.2


func _init() -> void:
	var actions: Dictionary = {
		"move_left": [_key(KEY_A), _key(KEY_LEFT), _axis(JOY_AXIS_LEFT_X, -1.0)],
		"move_right": [_key(KEY_D), _key(KEY_RIGHT), _axis(JOY_AXIS_LEFT_X, 1.0)],
		"move_up": [_key(KEY_W), _key(KEY_UP), _axis(JOY_AXIS_LEFT_Y, -1.0)],
		"move_down": [_key(KEY_S), _key(KEY_DOWN), _axis(JOY_AXIS_LEFT_Y, 1.0)],
		"aim_left": [_axis(JOY_AXIS_RIGHT_X, -1.0)],
		"aim_right": [_axis(JOY_AXIS_RIGHT_X, 1.0)],
		"aim_up": [_axis(JOY_AXIS_RIGHT_Y, -1.0)],
		"aim_down": [_axis(JOY_AXIS_RIGHT_Y, 1.0)],
		"attack_light": [_mouse(MOUSE_BUTTON_LEFT), _joy(JOY_BUTTON_RIGHT_SHOULDER)],
		"attack_heavy": [_mouse(MOUSE_BUTTON_RIGHT), _axis(JOY_AXIS_TRIGGER_RIGHT, 1.0)],
		"dodge": [_key(KEY_SPACE), _joy(JOY_BUTTON_B)],
		"ranged": [_key(KEY_Q), _joy(JOY_BUTTON_LEFT_SHOULDER), _axis(JOY_AXIS_TRIGGER_LEFT, 1.0)],
		"heal": [_key(KEY_R), _joy(JOY_BUTTON_X)],
		"interact": [_key(KEY_E), _joy(JOY_BUTTON_A)],
		"lock_on": [_key(KEY_TAB), _mouse(MOUSE_BUTTON_MIDDLE), _joy(JOY_BUTTON_RIGHT_STICK)],
		"target_next": [_mouse(MOUSE_BUTTON_WHEEL_DOWN), _joy(JOY_BUTTON_DPAD_RIGHT)],
		"target_prev": [_mouse(MOUSE_BUTTON_WHEEL_UP), _joy(JOY_BUTTON_DPAD_LEFT)],
		"pause": [_key(KEY_ESCAPE), _joy(JOY_BUTTON_START)],
		"debug_overlay": [_key(KEY_F3)],
		"debug_hitboxes": [_key(KEY_F4)],
		"debug_tuning": [_key(KEY_F6)],
		"feel_preset_next": [_key(KEY_F7)],
		"debug_spawn": [_key(KEY_F8)],
	}
	for action_name: String in actions:
		ProjectSettings.set_setting("input/" + action_name, {"deadzone": DEADZONE, "events": actions[action_name]})

	ProjectSettings.set_setting("shader_globals/player_position", {"type": "vec3", "value": Vector3.ZERO})
	ProjectSettings.set_setting("shader_globals/occlusion_radius", {"type": "float", "value": 0.16})
	ProjectSettings.set_setting("shader_globals/occlusion_enabled", {"type": "float", "value": 1.0})

	var err: Error = ProjectSettings.save()
	print("setup_project: saved project settings, result = ", err)
	quit(0 if err == OK else 1)


func _key(code: Key) -> InputEventKey:
	var ev := InputEventKey.new()
	ev.physical_keycode = code
	ev.device = -1
	return ev


func _mouse(button: MouseButton) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	ev.device = -1
	return ev


func _joy(button: JoyButton) -> InputEventJoypadButton:
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	ev.device = -1
	return ev


func _axis(axis: JoyAxis, value: float) -> InputEventJoypadMotion:
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	ev.device = -1
	return ev
