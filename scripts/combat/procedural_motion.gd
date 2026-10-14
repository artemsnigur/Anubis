class_name ProceduralMotion
extends RefCounted
## Procedural layers applied on top of any animation, on the character's Visual node:
## lean into turns, forward lean on acceleration, squash/stretch impulses (dashes,
## landings), additive hit recoil and a jitter while frozen by hitstop.

var body: CharacterBody3D
var visual: Node3D
var max_lean_deg: float = 14.0
var lean_per_turn: float = 0.11
var accel_pitch: float = 0.012
var enabled: bool = true

var _prev_yaw: float = 0.0
var _prev_speed: float = 0.0
var _roll: float = 0.0
var _pitch: float = 0.0
var _stretch: float = 0.0
var _stretch_vel: float = 0.0
var _recoil: Vector2 = Vector2.ZERO      # x = pitch, y = roll (radians)
var _recoil_vel: Vector2 = Vector2.ZERO
var _base_scale: Vector3 = Vector3.ONE


func setup(p_body: CharacterBody3D, p_visual: Node3D) -> void:
	body = p_body
	visual = p_visual
	_prev_yaw = body.rotation.y
	_base_scale = visual.scale


## Positive = stretch along Y (dash start), negative = squash (landing).
func stretch_impulse(amount: float) -> void:
	_stretch_vel += amount * 14.0


## Additive recoil away from a hit direction (world space).
func recoil(world_dir: Vector3, strength: float) -> void:
	var local := body.global_basis.inverse() * world_dir
	_recoil_vel += Vector2(local.z, -local.x) * strength * 9.0


func update(dt: float, real_dt: float, frozen: bool) -> void:
	if not enabled or visual == null:
		return
	if frozen:
		var j := 0.035
		visual.position = Vector3(randf_range(-j, j), randf_range(-j, j) * 0.5, randf_range(-j, j))
		return
	visual.position = Vector3.ZERO
	if dt <= 0.0:
		return
	var yaw := body.rotation.y
	var yaw_rate := angle_difference(_prev_yaw, yaw) / dt
	_prev_yaw = yaw
	var hv := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var speed := hv.length()
	var speed_k := clampf(speed / 6.0, 0.0, 1.0)
	var target_roll := clampf(yaw_rate * lean_per_turn * speed_k, -deg_to_rad(max_lean_deg), deg_to_rad(max_lean_deg))
	_roll = lerpf(_roll, target_roll, 1.0 - exp(-10.0 * dt))
	var accel := (speed - _prev_speed) / dt
	_prev_speed = speed
	var target_pitch := clampf(-accel * accel_pitch, -0.25, 0.25) - speed_k * 0.05
	_pitch = lerpf(_pitch, target_pitch, 1.0 - exp(-8.0 * dt))
	# Springs (semi-implicit Euler, real time so they settle during slow-mo too).
	var sdt := minf(real_dt, 0.05)
	_stretch_vel += (-_stretch * 220.0 - _stretch_vel * 16.0) * sdt
	_stretch += _stretch_vel * sdt
	_recoil_vel += (-_recoil * 260.0 - _recoil_vel * 18.0) * sdt
	_recoil += _recoil_vel * sdt
	var s := clampf(_stretch, -0.35, 0.35)
	visual.scale = _base_scale * Vector3(1.0 - s * 0.5, 1.0 + s, 1.0 - s * 0.5)
	visual.rotation = Vector3(_pitch + clampf(_recoil.x, -0.6, 0.6), 0.0, _roll + clampf(_recoil.y, -0.6, 0.6))


func reset() -> void:
	_roll = 0.0
	_pitch = 0.0
	_stretch = 0.0
	_stretch_vel = 0.0
	_recoil = Vector2.ZERO
	_recoil_vel = Vector2.ZERO
	if visual != null:
		visual.rotation = Vector3.ZERO
		visual.position = Vector3.ZERO
		visual.scale = _base_scale
	if body != null:
		_prev_yaw = body.rotation.y
