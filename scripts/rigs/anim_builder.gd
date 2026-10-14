class_name AnimBuilder
extends RefCounted
## Tiny keyframe DSL used to author placeholder clips in code.
##
## key(t, pose, ease): pose = { "Bone": Vector3(euler deg) or Quaternion,
##                              "@Bone": Vector3 position offset from rest,
##                              "^Bone": Vector3 scale }
## Each bone interpolates only between its own keys, so poses can be partial.
## Easing is baked by sampling at 30 Hz, so the result plays identically everywhere.

enum { LINEAR, IN, OUT, SNAP, INOUT, BACK, HOLD }

const SAMPLE_RATE := 30.0

var rig: PlaceholderRig
var anim_name: StringName
var length: float
var loop: bool
var _rot: Dictionary = {}    # bone -> Array[[t, Quaternion, ease]]
var _pos: Dictionary = {}    # bone -> Array[[t, Vector3, ease]]
var _scl: Dictionary = {}    # bone -> Array[[t, Vector3, ease]]
var _events: Array = []


func _init(p_rig: PlaceholderRig, p_name: StringName, p_length: float, p_loop: bool = false) -> void:
	rig = p_rig
	anim_name = p_name
	length = maxf(p_length, 0.05)
	loop = p_loop


func key(t: float, pose: Dictionary, ease_type: int = INOUT) -> AnimBuilder:
	var tt := clampf(t, 0.0, length)
	for k: Variant in pose:
		var key_name := String(k)
		var v: Variant = pose[k]
		if key_name.begins_with("@"):
			_append(_pos, key_name.substr(1), tt, v, ease_type)
		elif key_name.begins_with("^"):
			_append(_scl, key_name.substr(1), tt, v, ease_type)
		else:
			var q: Quaternion = v if v is Quaternion else euler(v as Vector3)
			_append(_rot, key_name, tt, q, ease_type)
	return self


func event(t: float, ev: StringName) -> AnimBuilder:
	_events.append([clampf(t, 0.0, length), ev])
	return self


func events(list: Array) -> AnimBuilder:
	for e: Array in list:
		event(float(e[0]), StringName(e[1]))
	return self


static func euler(deg: Vector3) -> Quaternion:
	return Basis.from_euler(Vector3(deg_to_rad(deg.x), deg_to_rad(deg.y), deg_to_rad(deg.z))).get_rotation_quaternion()


## Rotation that points a limb hanging along -Y toward a direction.
## yaw: 0 = forward(-Z), +90 = character's right(+X); elev: 0 = down, 90 = horizontal, 180 = up.
static func limb(yaw_deg: float, elev_deg: float, twist_deg: float = 0.0) -> Quaternion:
	var yaw := deg_to_rad(yaw_deg)
	var elev := deg_to_rad(elev_deg)
	var horiz := Vector3(sin(yaw), 0.0, -cos(yaw))
	var dir := (Vector3.DOWN * cos(elev) + horiz * sin(elev)).normalized()
	var q: Quaternion
	if dir.is_equal_approx(Vector3.DOWN):
		q = Quaternion.IDENTITY
	elif dir.is_equal_approx(Vector3.UP):
		q = Quaternion(Vector3.RIGHT, PI) if absf(yaw) < 0.01 else Quaternion(horiz.cross(Vector3.UP).normalized(), PI)
	else:
		q = Quaternion(Vector3.DOWN, dir)
	if absf(twist_deg) > 0.01:
		q = q * Quaternion(Vector3.DOWN, deg_to_rad(twist_deg))
	return q


static func ease_value(u: float, ease_type: int) -> float:
	match ease_type:
		LINEAR:
			return u
		IN:
			return u * u * u
		OUT:
			return 1.0 - pow(1.0 - u, 2.0)
		SNAP:
			return 1.0 - pow(1.0 - u, 4.0)
		INOUT:
			return u * u * (3.0 - 2.0 * u)
		BACK:
			var c1 := 1.70158
			var c3 := c1 + 1.0
			return 1.0 + c3 * pow(u - 1.0, 3.0) + c1 * pow(u - 1.0, 2.0)
		HOLD:
			return 0.0 if u < 0.999 else 1.0
	return u


func _append(dict: Dictionary, bone: String, t: float, v: Variant, ease_type: int) -> void:
	if not rig.bones.has(bone):
		return
	if not dict.has(bone):
		dict[bone] = []
	var list: Array = dict[bone]
	for i in list.size():
		if is_equal_approx(float(list[i][0]), t):
			list[i] = [t, v, ease_type]
			return
	list.append([t, v, ease_type])
	list.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))


func build() -> Animation:
	var anim := Animation.new()
	anim.length = length
	anim.loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	for bone: String in _rot:
		var idx := anim.add_track(Animation.TYPE_ROTATION_3D)
		anim.track_set_path(idx, rig.bone_path(bone))
		_sample(anim, idx, _rot[bone], 0, Vector3.ZERO)
	for bone: String in _pos:
		var idx := anim.add_track(Animation.TYPE_POSITION_3D)
		anim.track_set_path(idx, rig.bone_path(bone))
		_sample(anim, idx, _pos[bone], 1, rig.rest_position(bone))
	for bone: String in _scl:
		var idx := anim.add_track(Animation.TYPE_SCALE_3D)
		anim.track_set_path(idx, rig.bone_path(bone))
		_sample(anim, idx, _scl[bone], 2, Vector3.ONE)
	if not _events.is_empty():
		var midx := anim.add_track(Animation.TYPE_METHOD)
		anim.track_set_path(midx, NodePath("."))
		for e: Array in _events:
			anim.track_insert_key(midx, float(e[0]), {"method": &"anim_event", "args": [StringName(e[1]), anim_name]})
	return anim


# kind: 0 rotation, 1 position (offset from rest), 2 scale
func _sample(anim: Animation, idx: int, keys: Array, kind: int, rest_pos: Vector3) -> void:
	var list: Array = keys.duplicate()
	if float(list[0][0]) > 0.0:
		list.push_front([0.0, list[0][1], LINEAR])
	if loop:
		list.append([length, list[0][1], INOUT])
	elif float(list[list.size() - 1][0]) < length:
		list.append([length, list[list.size() - 1][1], HOLD])
	var step := 1.0 / SAMPLE_RATE
	_insert(anim, idx, kind, 0.0, list[0][1], rest_pos)
	for i in range(1, list.size()):
		var t0 := float(list[i - 1][0])
		var t1 := float(list[i][0])
		var v0: Variant = list[i - 1][1]
		var v1: Variant = list[i][1]
		var ease_type := int(list[i][2])
		var seg := t1 - t0
		if seg <= 0.0001:
			continue
		var n := maxi(1, int(ceil(seg / step)))
		for s in range(1, n + 1):
			var u := float(s) / float(n)
			var e := ease_value(u, ease_type)
			var value: Variant
			if kind == 0:
				value = (v0 as Quaternion).slerp(v1 as Quaternion, e)
			else:
				value = (v0 as Vector3).lerp(v1 as Vector3, e)
			_insert(anim, idx, kind, t0 + seg * u, value, rest_pos)


func _insert(anim: Animation, idx: int, kind: int, t: float, value: Variant, rest_pos: Vector3) -> void:
	match kind:
		0:
			anim.rotation_track_insert_key(idx, t, (value as Quaternion).normalized())
		1:
			anim.position_track_insert_key(idx, t, rest_pos + (value as Vector3))
		2:
			anim.scale_track_insert_key(idx, t, value as Vector3)
