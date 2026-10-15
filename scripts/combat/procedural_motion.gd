class_name ProceduralMotion
extends RefCounted
## Procedural layers applied on top of any animation, on the character's Visual node:
## lean into turns (roll) and into acceleration / counter-lean when braking (pitch),
## squash & stretch impulses (anticipation, dashes, landings), additive hit recoil,
## a visual push + shake when hit, and a jitter while frozen by hitstop.
## Leans are damped springs when lean_stiffness > 0 (they overshoot a little and settle,
## which reads as weight), otherwise plain exponential smoothing (the old behaviour).

var body: CharacterBody3D
var visual: Node3D
var max_lean_deg: float = 14.0
var lean_per_turn: float = 0.11
var accel_pitch: float = 0.012
var lean_stiffness: float = 0.0
var lean_damping: float = 0.0
var squash_scale: float = 1.0
var enabled: bool = true

var _prev_yaw: float = 0.0
var _prev_speed: float = 0.0
var _roll: float = 0.0
var _roll_vel: float = 0.0
var _pitch: float = 0.0
var _pitch_vel: float = 0.0
var _stretch: float = 0.0
var _stretch_vel: float = 0.0
var _recoil: Vector2 = Vector2.ZERO      # x = pitch, y = roll (radians)
var _recoil_vel: Vector2 = Vector2.ZERO
var _push: Vector3 = Vector3.ZERO        # visual offset (world), springs back
var _push_vel: Vector3 = Vector3.ZERO
var _shake: float = 0.0
var _base_scale: Vector3 = Vector3.ONE


func setup(p_body: CharacterBody3D, p_visual: Node3D) -> void:
	body = p_body
	visual = p_visual
	_prev_yaw = body.rotation.y
	_base_scale = visual.scale


## Copies the "Alive" lean / squash parameters of a feel preset.
func configure(feel: FeelPreset) -> void:
	max_lean_deg = feel.lean_max_deg
	lean_per_turn = feel.lean_turn
	accel_pitch = feel.lean_accel
	lean_stiffness = feel.lean_stiffness
	lean_damping = feel.lean_damping
	squash_scale = feel.squash


## Positive = stretch along Y (dash start), negative = squash (landing).
func stretch_impulse(amount: float) -> void:
	_stretch_vel += amount * 14.0


## Anticipation: an instant squash that springs back (shown on the input frame).
func anticipate(amount: float) -> void:
	if squash_scale <= 0.0:
		return
	_stretch = minf(_stretch, -0.07 * amount * squash_scale)
	_pitch_vel += 1.5 * amount * squash_scale


## Dodge: squash on the first frame, then the spring throws it into a stretch.
func dodge_squash() -> void:
	if squash_scale <= 0.0:
		stretch_impulse(0.28)
		return
	_stretch = -0.1 * squash_scale
	_stretch_vel = 5.5 * squash_scale


func land_squash(amount: float) -> void:
	if squash_scale > 0.0:
		_stretch_vel -= amount * 3.0 * squash_scale


## Skid: lean back against the old direction of travel (pivot / hard stop).
func skid(strength: float) -> void:
	if squash_scale > 0.0:
		_pitch_vel += 6.0 * strength
		_stretch_vel -= 1.2 * strength


## Additive recoil away from a hit direction (world space).
func recoil(world_dir: Vector3, strength: float) -> void:
	var local := body.global_basis.inverse() * world_dir
	_recoil_vel += Vector2(local.z, -local.x) * strength * 9.0


## Visual push (metres) along a world direction + a short shake: every hit reads,
## even on targets that resist knockback.
func push(world_dir: Vector3, metres: float, shake: float = 0.0) -> void:
	var d := Vector3(world_dir.x, 0.0, world_dir.z)
	if d.length_squared() > 0.0001:
		_push_vel += d.normalized() * metres * 28.0
	_shake = maxf(_shake, shake)


func update(dt: float, real_dt: float, frozen: bool) -> void:
	if not enabled or visual == null:
		return
	var to_local := body.global_basis.orthonormalized().inverse()
	if frozen:
		var j := 0.035 + _shake * 0.5
		visual.position = to_local * _push + Vector3(randf_range(-j, j), randf_range(-j, j) * 0.5, randf_range(-j, j))
		return
	var sdt := minf(real_dt, 0.05)
	# Springs (semi-implicit Euler, real time so they settle during slow-mo too).
	_push_vel += (-_push * 300.0 - _push_vel * 22.0) * sdt
	_push += _push_vel * sdt
	var shake_off := Vector3.ZERO
	if _shake > 0.001:
		shake_off = Vector3(randf_range(-1, 1), 0.0, randf_range(-1, 1)) * _shake
		_shake = maxf(_shake - 0.5 * sdt, 0.0) * exp(-14.0 * sdt)
	visual.position = to_local * (_push + shake_off)
	if dt <= 0.0:
		return
	var yaw := body.rotation.y
	var yaw_rate := angle_difference(_prev_yaw, yaw) / dt
	_prev_yaw = yaw
	var hv := Vector3(body.velocity.x, 0.0, body.velocity.z)
	var speed := hv.length()
	var speed_k := clampf(speed / 6.0, 0.0, 1.0)
	var lim := deg_to_rad(max_lean_deg)
	var target_roll := clampf(yaw_rate * lean_per_turn * speed_k, -lim, lim)
	var accel := (speed - _prev_speed) / dt
	_prev_speed = speed
	var target_pitch := clampf(-accel * accel_pitch, -0.25, 0.25) - speed_k * 0.05
	if lean_stiffness > 0.0:
		_roll_vel += ((target_roll - _roll) * lean_stiffness - _roll_vel * lean_damping) * sdt
		_roll += _roll_vel * sdt
		_pitch_vel += ((target_pitch - _pitch) * lean_stiffness - _pitch_vel * lean_damping) * sdt
		_pitch += _pitch_vel * sdt
	else:
		_roll = lerpf(_roll, target_roll, 1.0 - exp(-10.0 * dt))
		_pitch = lerpf(_pitch, target_pitch, 1.0 - exp(-8.0 * dt))
		_pitch += _pitch_vel * sdt
		_pitch_vel *= exp(-12.0 * sdt)
	_stretch_vel += (-_stretch * 220.0 - _stretch_vel * 16.0) * sdt
	_stretch += _stretch_vel * sdt
	_recoil_vel += (-_recoil * 260.0 - _recoil_vel * 18.0) * sdt
	_recoil += _recoil_vel * sdt
	var s := clampf(_stretch, -0.35, 0.35)
	visual.scale = _base_scale * Vector3(1.0 - s * 0.5, 1.0 + s, 1.0 - s * 0.5)
	visual.rotation = Vector3(clampf(_pitch, -0.45, 0.45) + clampf(_recoil.x, -0.6, 0.6), 0.0, clampf(_roll, -lim, lim) + clampf(_recoil.y, -0.6, 0.6))


func reset() -> void:
	_roll = 0.0
	_roll_vel = 0.0
	_pitch = 0.0
	_pitch_vel = 0.0
	_stretch = 0.0
	_stretch_vel = 0.0
	_recoil = Vector2.ZERO
	_recoil_vel = Vector2.ZERO
	_push = Vector3.ZERO
	_push_vel = Vector3.ZERO
	_shake = 0.0
	if visual != null:
		visual.rotation = Vector3.ZERO
		visual.position = Vector3.ZERO
		visual.scale = _base_scale
	if body != null:
		_prev_yaw = body.rotation.y
