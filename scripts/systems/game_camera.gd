class_name GameCamera
extends Node3D
## Fixed 3/4 isometric-style camera: perspective with a narrow FOV (or orthographic),
## pitched down and rotated 45 degrees, smooth follow with look-ahead (movement, aim,
## lock target), zoom (boss fight) and trauma-based FastNoiseLite shake.

@export_group("Framing")
@export var fov: float = 35.0
@export var pitch_deg: float = 52.0
@export var yaw_deg: float = 45.0
@export var distance: float = 14.0
@export var orthographic: bool = false
@export var ortho_size: float = 11.0
@export var target_height: float = 0.8

@export_group("Follow")
@export var follow_damping: float = 7.0
@export var look_ahead_damping: float = 2.5
@export var look_ahead_scale: float = 1.0
@export var zoom_damping: float = 1.5

@export_group("Shake")
@export var max_shake_offset: float = 0.55
@export var max_shake_roll_deg: float = 2.2
@export var trauma_decay: float = 1.7
@export var noise_speed: float = 24.0

var target: Node3D
var zoom: float = 1.0
var trauma: float = 0.0
var camera: Camera3D
var _zoom_current: float = 1.0
var _focus: Vector3 = Vector3.ZERO
var _look_ahead: Vector3 = Vector3.ZERO
var _noise := FastNoiseLite.new()
var _noise_t: float = 0.0
var _listener: AudioListener3D


func _ready() -> void:
	add_to_group(&"game_camera")
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.near = 0.5
	camera.far = 140.0
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	add_child(camera)
	camera.make_current()
	_listener = AudioListener3D.new()
	_listener.top_level = true
	add_child(_listener)
	_listener.make_current()
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.frequency = 0.5
	orthographic = orthographic or Settings.camera_orthographic
	_apply_projection()
	CameraShake.register_camera(self)
	Settings.changed.connect(func() -> void: set_orthographic(Settings.camera_orthographic))


func _exit_tree() -> void:
	CameraShake.unregister_camera(self)


func _apply_projection() -> void:
	if orthographic:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = ortho_size * _zoom_current
	else:
		camera.projection = Camera3D.PROJECTION_PERSPECTIVE
		camera.fov = fov


func set_orthographic(value: bool) -> void:
	orthographic = value
	_apply_projection()


func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func get_focus_position() -> Vector3:
	return _focus


## Instantly centres on the target (after teleports / respawn).
func snap_to_target() -> void:
	if target == null:
		return
	_focus = target.global_position + Vector3.UP * target_height
	_look_ahead = Vector3.ZERO
	_zoom_current = zoom
	_update_transform(0.0)


func _process(delta: float) -> void:
	if target != null and is_instance_valid(target):
		var tpos := target.get_global_transform_interpolated().origin + Vector3.UP * target_height
		var desired_la := Vector3.ZERO
		if target.has_method(&"camera_look_ahead"):
			desired_la = (target.call(&"camera_look_ahead") as Vector3) * look_ahead_scale
		_look_ahead = _look_ahead.lerp(desired_la, 1.0 - exp(-look_ahead_damping * delta))
		_focus = _focus.lerp(tpos + _look_ahead, 1.0 - exp(-follow_damping * delta))
	_zoom_current = lerpf(_zoom_current, zoom, 1.0 - exp(-zoom_damping * delta))
	trauma = maxf(trauma - trauma_decay * delta, 0.0)
	_noise_t += delta * noise_speed
	_update_transform(delta)


func _update_transform(_delta: float) -> void:
	global_position = _focus
	rotation = Vector3(0.0, deg_to_rad(yaw_deg), 0.0)
	var pitch := deg_to_rad(pitch_deg)
	var d := distance * _zoom_current
	var shake := trauma * trauma * Settings.shake_strength
	var ox := _noise.get_noise_2d(_noise_t, 0.0) * max_shake_offset * shake
	var oy := _noise.get_noise_2d(0.0, _noise_t) * max_shake_offset * shake
	var roll := _noise.get_noise_2d(_noise_t, 100.0) * deg_to_rad(max_shake_roll_deg) * shake
	camera.position = Vector3(ox, sin(pitch) * d + oy, cos(pitch) * d)
	camera.rotation = Vector3(-pitch, 0.0, roll)
	if orthographic:
		camera.size = ortho_size * _zoom_current
	_listener.global_transform = Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), _focus + Vector3.UP * 2.0)
