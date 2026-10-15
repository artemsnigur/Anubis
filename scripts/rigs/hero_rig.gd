class_name HeroRig
extends PlaceholderRig
## The awakened ushabti: turquoise faience figurine with gold veins, striped lapis wig,
## gold usekh collar and a straight bronze sword. Clips are generated from the player's
## AttackData. Sword poses are authored as "where is the grip, where does the blade point,
## which way does the edge face" relative to the chest; arm IK (_sword) turns that into
## shoulder / elbow / wrist rotations, so swings follow real arcs and the torso drives them.

const L := AnimBuilder.LINEAR
const IN := AnimBuilder.IN
const OUT := AnimBuilder.OUT
const SNAP := AnimBuilder.SNAP
const INOUT := AnimBuilder.INOUT
const BACK := AnimBuilder.BACK
const GAIT_LENGTH := 0.6
# Arm chain (chest space) used by the sword IK.
const SOCKET_OFFSET := Vector3(0, -0.06, -0.01)
const SOCKET_ROT := Vector3(90, 0, 0)
const SHOULDER_R := Vector3(0.26, 0.2, 0)
const SHOULDER_L := Vector3(-0.26, 0.2, 0)
const UPPER_ARM := 0.3
const FOREARM := 0.27


func _build_body() -> void:
	var faience := Mats.get_mat(&"faience")
	var gold := Mats.get_mat(&"gold")
	var lapis := Mats.get_mat(&"lapis_char")
	var kilt := Mats.get_mat(&"kilt")
	var black := Mats.get_mat(&"black_glaze")

	add_bone("Body", "", Vector3.ZERO)
	add_bone("Hips", "Body", Vector3(0, 0.95, 0))
	part("Hips", box(Vector3(0.34, 0.18, 0.22)), faience)
	part("Hips", cylinder(0.2, 0.28, 0.34), kilt, Vector3(0, -0.12, 0))
	part("Hips", torus(0.19, 0.23), gold, Vector3(0, 0.04, 0), Vector3.ZERO, Vector3(1.0, 0.6, 0.85))
	# Secondary-motion pivots (driven by HeroAlive springs): gold kilt panel and two
	# linen sash tails hanging from the back of the belt.
	add_bone("KiltFlap", "Hips", Vector3(0, 0.03, -0.13))
	part("KiltFlap", box(Vector3(0.1, 0.3, 0.03)), gold, Vector3(0, -0.15, 0))
	var linen := Mats.get_mat(&"linen")
	for side in [-1.0, 1.0]:
		var sn := "SashL" if side < 0.0 else "SashR"
		add_bone(sn + "1", "Hips", Vector3(0.07 * side, 0.02, 0.15))
		part(sn + "1", box(Vector3(0.06, 0.2, 0.015)), linen, Vector3(0, -0.1, 0))
		add_bone(sn + "2", sn + "1", Vector3(0, -0.2, 0))
		part(sn + "2", box(Vector3(0.052, 0.17 if side < 0.0 else 0.2, 0.014)), linen, Vector3(0, -0.09, 0))

	add_bone("Spine", "Hips", Vector3(0, 0.1, 0))
	part("Spine", capsule(0.15, 0.34), faience, Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(1.05, 1.0, 0.8))
	add_bone("Chest", "Spine", Vector3(0, 0.24, 0))
	part("Chest", box(Vector3(0.44, 0.3, 0.24)), faience, Vector3(0, 0.1, 0))
	# Usekh collar: stacked gold / lapis rings.
	part("Chest", cylinder(0.15, 0.3, 0.05), gold, Vector3(0, 0.27, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
	part("Chest", cylinder(0.16, 0.31, 0.04), lapis, Vector3(0, 0.23, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
	part("Chest", cylinder(0.17, 0.32, 0.04), gold, Vector3(0, 0.195, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))

	add_bone("Neck", "Chest", Vector3(0, 0.29, 0))
	part("Neck", cylinder(0.06, 0.065, 0.12), faience, Vector3(0, 0.03, 0))
	add_bone("Head", "Neck", Vector3(0, 0.08, 0))
	part("Head", box(Vector3(0.19, 0.23, 0.2)), faience, Vector3(0, 0.12, -0.01))
	# Tripartite wig with lappets.
	part("Head", box(Vector3(0.31, 0.27, 0.25)), lapis, Vector3(0, 0.17, 0.04))
	part("Head", box(Vector3(0.315, 0.035, 0.255)), gold, Vector3(0, 0.12, 0.04))
	part("Head", box(Vector3(0.315, 0.035, 0.255)), gold, Vector3(0, 0.2, 0.04))
	# Wig lappets on spring pivots at the temples.
	add_bone("LappetR", "Head", Vector3(0.12, 0.11, -0.06))
	part("LappetR", box(Vector3(0.08, 0.26, 0.07)), lapis, Vector3(0, -0.13, 0), Vector3(0, 0, -4))
	add_bone("LappetL", "Head", Vector3(-0.12, 0.11, -0.06))
	part("LappetL", box(Vector3(0.08, 0.26, 0.07)), lapis, Vector3(0, -0.13, 0), Vector3(0, 0, 4))
	part("Head", box(Vector3(0.05, 0.13, 0.05)), gold, Vector3(0, -0.02, -0.1), Vector3(-10, 0, 0))
	part("Head", box(Vector3(0.05, 0.022, 0.02)), Mats.get_mat(&"eye_gold"), Vector3(0.048, 0.15, -0.112))
	part("Head", box(Vector3(0.05, 0.022, 0.02)), Mats.get_mat(&"eye_gold"), Vector3(-0.048, 0.15, -0.112))
	part("Head", box(Vector3(0.06, 0.01, 0.02)), black, Vector3(0.048, 0.178, -0.11))
	part("Head", box(Vector3(0.06, 0.01, 0.02)), black, Vector3(-0.048, 0.178, -0.11))

	for side in [1.0, -1.0]:
		var s := "R" if side > 0.0 else "L"
		add_bone("Arm" + s, "Chest", Vector3(0.26 * side, 0.2, 0))
		part("Arm" + s, sphere(0.09), faience)
		part("Arm" + s, capsule(0.066, 0.34), faience, Vector3(0, -0.15, 0))
		add_bone("Forearm" + s, "Arm" + s, Vector3(0, -0.3, 0))
		part("Forearm" + s, capsule(0.056, 0.3), faience, Vector3(0, -0.13, 0))
		part("Forearm" + s, torus(0.045, 0.07), gold, Vector3(0, -0.2, 0))
		add_bone("Hand" + s, "Forearm" + s, Vector3(0, -0.27, 0))
		part("Hand" + s, box(Vector3(0.08, 0.1, 0.09)), faience, Vector3(0, -0.045, 0))
		add_bone("Leg" + s, "Hips", Vector3(0.11 * side, -0.07, 0))
		part("Leg" + s, capsule(0.085, 0.44), faience, Vector3(0, -0.2, 0))
		add_bone("Shin" + s, "Leg" + s, Vector3(0, -0.42, 0))
		part("Shin" + s, capsule(0.068, 0.42), faience, Vector3(0, -0.2, 0))
		part("Shin" + s, torus(0.05, 0.08), gold, Vector3(0, -0.33, 0))
		add_bone("Foot" + s, "Shin" + s, Vector3(0, -0.41, 0))
		part("Foot" + s, box(Vector3(0.1, 0.07, 0.23)), faience, Vector3(0, -0.02, -0.05))

	# Sword in the right hand. The socket's -Y runs out of the fist (blade), +Z / -Z are
	# the edges; the arm IK below orients the hand so the blade points where a pose says.
	var socket := add_socket(&"weapon_r", "HandR", SOCKET_OFFSET, SOCKET_ROT)
	var parts := SwordMesh.attach(socket, Mats.get_mat(&"bronze"), gold, Mats.get_mat(&"wood"))
	sockets[&"blade"] = parts["blade"]
	sockets[&"trail_base"] = parts["base"]
	sockets[&"trail_tip"] = parts["tip"]
	add_socket(&"hand_l", "HandL", Vector3(0, -0.08, -0.04))
	add_socket(&"chest", "Chest", Vector3(0, 0.15, -0.15))
	add_socket(&"head", "Head", Vector3(0, 0.15, -0.1))


# --- sword IK ---------------------------------------------------------------------

## Arm rotations (chest space) that put the sword grip at `hilt`, the blade along `blade`
## and the leading edge facing `edge`. With `two_hands` the left hand grips the hilt below
## the right one. Returns a partial pose for AnimBuilder.key().
static func sword(hilt: Vector3, blade: Vector3, edge: Vector3, two_hands: bool = false,
		pole: Vector3 = Vector3(0.6, -0.5, 0.5)) -> Dictionary:
	var y := -blade.normalized()
	var e := edge - y * edge.dot(y)
	if e.length_squared() < 0.0001:
		e = Vector3.FORWARD - y * Vector3.FORWARD.dot(y)
	var z := -e.normalized()
	var socket_basis := Basis(y.cross(z), y, z)
	var hand_basis := socket_basis * Basis.from_euler(SOCKET_ROT * (PI / 180.0)).inverse()
	var wrist := hilt - hand_basis * SOCKET_OFFSET
	var arm := _arm_ik(SHOULDER_R, wrist, pole)
	var upper: Basis = arm[0]
	var fore_local: Basis = arm[1]
	var pose := {
		"ArmR": upper.get_rotation_quaternion(),
		"ForearmR": fore_local.get_rotation_quaternion(),
		"HandR": ((upper * fore_local).inverse() * hand_basis).get_rotation_quaternion(),
	}
	if two_hands:
		var grip_l := hilt + y * 0.11
		var arm_l := _arm_ik(SHOULDER_L, grip_l - hand_basis * SOCKET_OFFSET, Vector3(-pole.x, pole.y, pole.z))
		var up_l: Basis = arm_l[0]
		var fo_l: Basis = arm_l[1]
		pose["ArmL"] = up_l.get_rotation_quaternion()
		pose["ForearmL"] = fo_l.get_rotation_quaternion()
		pose["HandL"] = ((up_l * fo_l).inverse() * hand_basis).get_rotation_quaternion()
	return pose


## Two-bone IK in chest space: shoulder -> wrist with the elbow bent toward `pole`.
## Returns [upper arm basis (relative to the chest), forearm basis (relative to the upper arm)].
static func _arm_ik(shoulder: Vector3, wrist: Vector3, pole: Vector3) -> Array:
	var to := wrist - shoulder
	var d := clampf(to.length(), 0.05, (UPPER_ARM + FOREARM) * 0.995)
	var dir := to.normalized()
	var a := (UPPER_ARM * UPPER_ARM + d * d - FOREARM * FOREARM) / (2.0 * d)
	var h := sqrt(maxf(UPPER_ARM * UPPER_ARM - a * a, 0.0))
	var p := pole - dir * pole.dot(dir)
	if p.length_squared() < 0.0001:
		p = Vector3.DOWN - dir * Vector3.DOWN.dot(dir)
	var elbow := shoulder + dir * a + p.normalized() * h
	var d1 := (elbow - shoulder).normalized()
	var d2 := (shoulder + dir * d - elbow).normalized()
	var yu := -d1
	var perp := d2 - d1 * d1.dot(d2)
	var zu := -perp.normalized() if perp.length_squared() > 0.000001 else Vector3.BACK
	var upper := Basis(yu.cross(zu), yu, zu).orthonormalized()
	var bend := acos(clampf(d1.dot(d2), -1.0, 1.0))
	return [upper, Basis(Vector3.RIGHT, bend)]


## Same as sword(), but hilt / blade / edge are given in root space (origin between the
## feet, facing -Z, +X = right): converted through the torso of `pose` (@Hips, Hips,
## Spine, Chest), so a swing can be authored as an arc around the body regardless of how
## far the torso twists. `pose` should be a full key (merged with the stance).
func sword_root(pose: Dictionary, hilt: Vector3, blade: Vector3, edge: Vector3, two_hands: bool = false,
		pole: Vector3 = Vector3(0.6, -0.5, 0.5)) -> Dictionary:
	var hips := Transform3D(_key_basis(pose, "Hips"), rest_position("Hips") + (pose.get("@Hips", Vector3.ZERO) as Vector3))
	var spine := Transform3D(_key_basis(pose, "Spine"), rest_position("Spine"))
	var chest := Transform3D(_key_basis(pose, "Chest"), rest_position("Chest"))
	var inv := (hips * spine * chest).affine_inverse()
	return sword(inv * hilt, inv.basis * blade, inv.basis * edge, two_hands, pole)


func _key_basis(pose: Dictionary, bone: String) -> Basis:
	var v: Variant = pose.get(bone, Vector3.ZERO)
	if v is Quaternion:
		return Basis(v as Quaternion)
	return Basis.from_euler((v as Vector3) * (PI / 180.0))


## A full key: stance merged with `body`, plus the sword placed in root space.
func _sk(st: Dictionary, body: Dictionary, hilt: Vector3, blade: Vector3, edge: Vector3, two_hands: bool = false,
		pole: Vector3 = Vector3(0.6, -0.5, 0.5)) -> Dictionary:
	var full := _merge(st, body)
	return _merge(full, sword_root(full, hilt, blade, edge, two_hands, pole))


# --- poses ------------------------------------------------------------------------

## Guard: feet wide, knees soft, weight centred; sword low in front, point forward-down.
func _stance() -> Dictionary:
	return _merge({
		"@Hips": Vector3(0, -0.09, 0), "Hips": Vector3(0, -14, 0),
		"Spine": Vector3(-8, 6, 0), "Chest": Vector3(-4, 6, 0), "Neck": Vector3(4, -2, 0), "Head": Vector3(4, 4, 0),
		"ArmL": AnimBuilder.limb(-35, 30), "ForearmL": Vector3(55, 0, 0), "HandL": Vector3(0, 0, 0),
		"LegR": Vector3(-12, 0, 7), "ShinR": Vector3(-32, 0, 0), "FootR": Vector3(24, 0, -6),
		"LegL": Vector3(16, 0, -7), "ShinL": Vector3(-28, 0, 0), "FootL": Vector3(8, 0, 6),
		"^Body": Vector3.ONE,
	}, guard_sword())


static func guard_sword() -> Dictionary:
	return sword(Vector3(0.18, -0.3, -0.32), Vector3(-0.15, -0.2, -0.97), Vector3(0, -1, 0))


func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var r := a.duplicate()
	for k: Variant in b:
		r[k] = b[k]
	return r


func _build_clips(lib: AnimationLibrary) -> void:
	var st := _stance()
	_idle(lib, st)
	# Same cycle length for walk and run so the synced blend keeps the feet in phase;
	# the animator rescales playback from the stride so the feet stay planted. Low hips,
	# bent knees and a deep bob make the body read heavy.
	_gait(lib, &"walk", GAIT_LENGTH, 1.5, 0.6, 0.09, -0.06, 0.025, 0.0)
	_gait(lib, &"run", GAIT_LENGTH, 3.1, 0.33, 0.26, -0.1, 0.055, 1.0)
	_light_1(lib, st)
	_light_2(lib, st)
	_light_3(lib, st)
	_heavy(lib, st)
	_dodge(lib, st)
	_hit(lib, st)
	_death(lib, st)
	_heal(lib, st)
	_cast(lib, st)
	_rest(lib, st)
	_grabbed(lib, st)
	_interact(lib, st)


func _timing(clip: StringName) -> Dictionary:
	return clip_table.get(clip, {})


func _idle(lib: AnimationLibrary, st: Dictionary) -> void:
	var b := AnimBuilder.new(self, &"idle", 2.4, true)
	b.key(0.0, st)
	b.key(1.2, _merge({"@Hips": Vector3(0, -0.1, 0), "Chest": Vector3(-2, 7, 0), "Head": Vector3(6, 2, 0),
		"ShinR": Vector3(-33, 0, 0), "ShinL": Vector3(-29, 0, 0), "ArmL": AnimBuilder.limb(-36, 33)},
		sword(Vector3(0.18, -0.31, -0.33), Vector3(-0.2, -0.24, -0.95), Vector3(0, -1, 0))))
	lib.add_animation(&"idle", b.build())


## Foot-locked locomotion cycle (walk / run) for the hero.
## The stance foot is solved with 2-bone IK so it stays planted while the hips travel
## `stride` metres per cycle; the clip carries the stride as metadata, and the animator
## scales playback so the cycle matches the real speed (no foot sliding).
## stride: metres travelled per cycle (two steps); stance: fraction of the cycle a foot is
## planted; lift: swing foot height; bob: hip bob; k: 0 = walk, 1 = run (style blend).
func _gait(lib: AnimationLibrary, clip: StringName, length: float, stride: float, stance: float, lift: float, base_hip: float, bob: float, k: float) -> void:
	const THIGH := 0.42
	const SHIN := 0.41
	const FOOT_H := 0.055
	var hip_joint := 0.95 - 0.07
	var sweep := stride * stance
	var touchdown := sweep * 0.5
	var reach := (THIGH + SHIN) * 0.985
	var b := AnimBuilder.new(self, clip, length, true)
	var n := int(round(length * AnimBuilder.SAMPLE_RATE))
	for i in n:
		var ph := float(i) / float(n)
		var feet: Array = []     # [forward, height, planted]
		for side in 2:
			var lp := fposmod(ph + 0.5 * side, 1.0)
			if lp < stance:
				var u := lp / stance
				feet.append([touchdown - u * sweep, FOOT_H + 0.05 * pow(maxf(u - 0.7, 0.0) / 0.3, 2.0), true, u])
			else:
				var u := (lp - stance) / (1.0 - stance)
				var e := u * u * (3.0 - 2.0 * u)
				feet.append([touchdown - sweep + e * sweep, FOOT_H + 0.05 * (1.0 - u) + lift * sin(PI * pow(u, 0.8)), false, u])
		var hip := base_hip - bob * cos(TAU * 2.0 * (ph - stance * 0.5))
		for f: Array in feet:
			if f[2]:
				var x: float = f[0]
				hip = minf(hip, float(f[1]) + sqrt(maxf(reach * reach - x * x, 0.0)) - hip_joint)
		var pose := {"@Hips": Vector3(0, hip, 0)}
		for side in 2:
			var s := "R" if side == 0 else "L"
			var f: Array = feet[side]
			var x: float = f[0]
			var down := hip_joint + hip - float(f[1])
			var d := minf(sqrt(x * x + down * down), (THIGH + SHIN) * 0.999)
			var knee := acos(clampf((THIGH * THIGH + SHIN * SHIN - d * d) / (2.0 * THIGH * SHIN), -1.0, 1.0))
			var a := acos(clampf((THIGH * THIGH + d * d - SHIN * SHIN) / (2.0 * THIGH * d), -1.0, 1.0))
			var thigh := atan2(x, down) + a
			var shin := -(PI - knee)
			# Foot: flat while planted (toe rolls at push-off), toes hang in the swing.
			var foot := -(thigh + shin)
			if f[2]:
				foot -= deg_to_rad(28.0) * pow(maxf(float(f[3]) - 0.7, 0.0) / 0.3, 2.0)
			else:
				foot -= deg_to_rad(18.0 + 10.0 * k) * sin(PI * float(f[3]))
			pose["Leg" + s] = Vector3(rad_to_deg(thigh), 0, 0)
			pose["Shin" + s] = Vector3(rad_to_deg(shin), 0, 0)
			pose["Foot" + s] = Vector3(rad_to_deg(foot), 0, 0)
		# Upper body: forward lean, hip / chest counter-twist, arms swing against the legs.
		var swing := sin(TAU * ph)   # +1 when the right leg is forward
		var lean := -6.0 - 12.0 * k
		# No hip yaw: it would swing the planted foot. The twist lives in spine / chest.
		pose["Hips"] = Vector3.ZERO
		pose["Spine"] = Vector3(lean, (3.0 + 5.0 * k) * swing, 0)
		pose["Chest"] = Vector3(-2.0 * k, -(9.0 * k + 6.0) * swing, 0)
		pose["Neck"] = Vector3(-lean * 0.45, 0, 0)
		pose["Head"] = Vector3(-lean * 0.3, (4.0 * k + 2.0) * swing, 0)
		var blade_dir := Vector3(-0.12, -0.5, -0.86).lerp(Vector3(0.14, -0.42, 0.9), k).normalized()
		pose.merge(sword(Vector3(0.27, -0.36 - 0.05 * k, -0.16 + 0.1 * k - 0.07 * swing), blade_dir, Vector3(0, -1, 0)), true)
		pose["ArmL"] = AnimBuilder.limb(-15.0 - 8.0 * swing, 16.0 + 16.0 * k + (22.0 + 20.0 * k) * swing)
		pose["ForearmL"] = Vector3(35.0 + 35.0 * k + 15.0 * swing, 0, 0)
		pose["^Body"] = Vector3.ONE
		b.key(length * ph, pose, AnimBuilder.LINEAR)
	b.event(0.02, &"footstep_r").event(length * 0.5 + 0.02, &"footstep_l")
	var anim := b.build()
	anim.set_meta(&"stride", stride)
	lib.add_animation(clip, anim)


func _attack_times(clip: StringName, def_w: float, def_a: float, def_r: float) -> Array:
	var t := _timing(clip)
	var w := float(t.get("windup", def_w))
	var a := float(t.get("active", def_a))
	var r := float(t.get("recovery", def_r))
	return [w, a, r]


func _attack_events(b: AnimBuilder, w: float, a: float) -> void:
	# Whoosh as the blade starts to accelerate; the trail only covers the cut itself.
	b.event(maxf(w * 0.55, 0.017), &"swing")
	b.event(maxf(w - 0.06, 0.017), &"trail_on")
	b.event(maxf(w, 0.017), &"hitbox_on")
	b.event(w + a, &"hitbox_off")


# --- sword attacks ------------------------------------------------------------------
# Every swing: a small weight drop on the first frame (the body reacts at once), a coil
# that cocks the sword with a beat of tension, an accelerating strike with a step, a
# follow-through that is held, then a recovery back into the guard. The torso twist
# drives the blade (negative Y = turned right, positive = left).

const HIPS_LOW := -0.17


func _light_1(lib: AnimationLibrary, st: Dictionary) -> void:
	var tm := _attack_times(&"light_1", 0.24, 0.1, 0.42)
	var w: float = tm[0]
	var a: float = tm[1]
	var r: float = tm[2]
	var b := AnimBuilder.new(self, &"light_1", w + a + r)
	b.key(0.0, st)
	# Weight drops and turns into the back leg straight away.
	b.key(w * 0.18, _sk(st, {"@Hips": Vector3(0, -0.12, 0.02), "Hips": Vector3(0, -18, 0), "Chest": Vector3(-2, -6, 0),
		"^Body": Vector3(1.03, 0.96, 1.03)}, Vector3(0.36, 1.05, -0.2), Vector3(0.1, 0.2, -0.97), Vector3(0, -1, 0)), OUT)
	var coil := {"@Hips": Vector3(0, -0.13, 0.04), "Hips": Vector3(0, -30, 0), "Spine": Vector3(-4, -16, 0),
		"Chest": Vector3(-2, -28, 4), "Neck": Vector3(2, 14, 0), "Head": Vector3(4, 14, 0),
		"ArmL": AnimBuilder.limb(-60, 55), "ForearmL": Vector3(70, 0, 0),
		"LegR": Vector3(-14, 0, 6), "ShinR": Vector3(-38, 0, 0), "FootR": Vector3(30, 0, 0),
		"LegL": Vector3(16, 0, -8), "ShinL": Vector3(-16, 0, 0), "FootL": Vector3(0, 0, 0), "^Body": Vector3(0.98, 1.03, 0.98)}
	# Cocked over the right shoulder, edge toward the cut.
	b.key(w * 0.7, _sk(st, coil, Vector3(0.44, 1.75, 0.16), Vector3(0.38, 0.55, 0.74), Vector3(-0.6, -0.3, -0.74)), INOUT)
	b.key(w * 0.84, _sk(st, _merge(coil, {"Chest": Vector3(-2, -31, 5), "@Hips": Vector3(0, -0.135, 0.05)}),
		Vector3(0.46, 1.77, 0.19), Vector3(0.4, 0.52, 0.75), Vector3(-0.6, -0.3, -0.74)), L)
	var strike := {"@Hips": Vector3(0, HIPS_LOW, -0.06), "Hips": Vector3(0, 14, 0), "Spine": Vector3(-14, 14, 0),
		"Chest": Vector3(-8, 26, -4), "Neck": Vector3(6, -14, 0), "Head": Vector3(8, -12, 0),
		"ArmL": AnimBuilder.limb(-110, 40), "ForearmL": Vector3(35, 0, 0),
		"LegL": Vector3(36, 0, -6), "ShinL": Vector3(-40, 0, 0), "FootL": Vector3(4, 0, 0),
		"LegR": Vector3(-26, 0, 6), "ShinR": Vector3(-26, 0, 0), "FootR": Vector3(30, 0, 0), "^Body": Vector3(1.04, 0.95, 1.04)}
	# Accelerate down through the high front into the contact.
	b.key(w, _sk(st, _merge(strike, {"Hips": Vector3(0, -4, 0), "Spine": Vector3(-8, -2, 0), "Chest": Vector3(-4, 0, 0), "@Hips": Vector3(0, -0.15, -0.02)}),
		Vector3(0.36, 1.68, -0.38), Vector3(0.12, 0.72, -0.68), Vector3(-0.55, -0.55, -0.62)), IN)
	b.key(w + a * 0.5, _sk(st, strike, Vector3(0.1, 1.3, -0.66), Vector3(-0.55, -0.15, -0.82), Vector3(-0.45, -0.89, 0.0)), L)
	b.key(w + a, _sk(st, strike, Vector3(-0.16, 1.04, -0.56), Vector3(-0.8, -0.45, -0.4), Vector3(-0.2, -0.9, 0.4)), L)
	var follow := _merge(strike, {"Hips": Vector3(0, 22, 0), "Spine": Vector3(-16, 18, 0), "Chest": Vector3(-8, 34, -4),
		"@Hips": Vector3(0, HIPS_LOW - 0.01, -0.07)})
	b.key(w + a + r * 0.25, _sk(st, follow, Vector3(-0.32, 0.9, -0.3), Vector3(-0.66, -0.6, 0.45), Vector3(0.3, -0.35, 0.89)), OUT)
	b.key(w + a + r * 0.45, _sk(st, _merge(follow, {"Chest": Vector3(-7, 32, -4), "^Body": Vector3.ONE}),
		Vector3(-0.3, 0.92, -0.32), Vector3(-0.64, -0.6, 0.48), Vector3(0.3, -0.35, 0.89)), L)
	b.key(w + a + r, st, INOUT)
	_attack_events(b, w, a)
	lib.add_animation(&"light_1", b.build())


## Rising backhand from the low-left finish of the first cut to high right.
func _light_2(lib: AnimationLibrary, st: Dictionary) -> void:
	var tm := _attack_times(&"light_2", 0.2, 0.1, 0.42)
	var w: float = tm[0]
	var a: float = tm[1]
	var r: float = tm[2]
	var b := AnimBuilder.new(self, &"light_2", w + a + r)
	var from := {"@Hips": Vector3(0, HIPS_LOW, -0.06), "Hips": Vector3(0, 20, 0), "Spine": Vector3(-14, 16, 0),
		"Chest": Vector3(-8, 30, -4), "LegL": Vector3(30, 0, -6), "ShinL": Vector3(-36, 0, 0), "LegR": Vector3(-22, 0, 6), "ShinR": Vector3(-28, 0, 0)}
	b.key(0.0, _sk(st, from, Vector3(-0.3, 0.92, -0.32), Vector3(-0.64, -0.6, 0.48), Vector3(0.3, -0.35, 0.89)))
	b.key(w * 0.25, _sk(st, _merge(from, {"@Hips": Vector3(0, -0.19, -0.04), "^Body": Vector3(1.03, 0.96, 1.03)}),
		Vector3(-0.32, 0.88, -0.22), Vector3(-0.62, -0.62, 0.48), Vector3(0.5, 0.6, -0.6)), OUT)
	var coiled := _merge(from, {"Hips": Vector3(0, 28, 0), "Spine": Vector3(-12, 20, 0), "Chest": Vector3(-6, 38, -4),
		"Neck": Vector3(4, -18, 0), "Head": Vector3(6, -16, 0), "@Hips": Vector3(0, -0.18, -0.04),
		"ArmL": AnimBuilder.limb(-20, 35), "ForearmL": Vector3(60, 0, 0)})
	b.key(w * 0.75, _sk(st, coiled, Vector3(-0.36, 0.84, -0.08), Vector3(-0.6, -0.55, 0.58), Vector3(0.55, 0.6, -0.58)), INOUT)
	var strike := {"@Hips": Vector3(0, HIPS_LOW, -0.08), "Hips": Vector3(0, -16, 0), "Spine": Vector3(-12, -14, 0),
		"Chest": Vector3(-4, -26, 4), "Neck": Vector3(4, 12, 0), "Head": Vector3(6, 10, 0),
		"ArmL": AnimBuilder.limb(-40, 30), "ForearmL": Vector3(70, 0, 0),
		"LegR": Vector3(34, 0, 6), "ShinR": Vector3(-40, 0, 0), "FootR": Vector3(4, 0, 0),
		"LegL": Vector3(-24, 0, -6), "ShinL": Vector3(-28, 0, 0), "FootL": Vector3(30, 0, 0), "^Body": Vector3(0.97, 1.04, 0.97)}
	b.key(w, _sk(st, _merge(strike, {"Hips": Vector3(0, 10, 0), "Spine": Vector3(-12, 6, 0), "Chest": Vector3(-6, 14, 0)}),
		Vector3(-0.16, 0.96, -0.58), Vector3(-0.3, -0.42, -0.86), Vector3(0.45, 0.85, -0.28)), IN)
	b.key(w + a * 0.5, _sk(st, strike, Vector3(0.12, 1.2, -0.64), Vector3(0.55, 0.35, -0.76), Vector3(0.3, 0.94, 0.15)), L)
	b.key(w + a, _sk(st, strike, Vector3(0.36, 1.45, -0.46), Vector3(0.8, 0.5, -0.33), Vector3(0.0, 0.6, 0.8)), L)
	var follow := _merge(strike, {"Hips": Vector3(0, -22, 0), "Chest": Vector3(-2, -34, 4), "@Hips": Vector3(0, -0.15, -0.08)})
	b.key(w + a + r * 0.25, _sk(st, follow, Vector3(0.44, 1.66, -0.2), Vector3(0.55, 0.75, 0.37), Vector3(-0.3, -0.25, 0.92)), OUT)
	b.key(w + a + r * 0.45, _sk(st, _merge(follow, {"Chest": Vector3(-2, -32, 4), "^Body": Vector3.ONE}),
		Vector3(0.42, 1.63, -0.22), Vector3(0.55, 0.74, 0.39), Vector3(-0.3, -0.25, 0.92)), L)
	b.key(w + a + r, st, INOUT)
	_attack_events(b, w, a)
	lib.add_animation(&"light_2", b.build())


## Finisher: two-handed overhead chop with a big step and a deep, held crouch.
func _light_3(lib: AnimationLibrary, st: Dictionary) -> void:
	var tm := _attack_times(&"light_3", 0.36, 0.12, 0.62)
	var w: float = tm[0]
	var a: float = tm[1]
	var r: float = tm[2]
	var b := AnimBuilder.new(self, &"light_3", w + a + r)
	var from := {"@Hips": Vector3(0, -0.15, -0.08), "Hips": Vector3(0, -20, 0), "Chest": Vector3(-2, -30, 4),
		"LegR": Vector3(30, 0, 6), "ShinR": Vector3(-36, 0, 0), "LegL": Vector3(-22, 0, -6), "ShinL": Vector3(-28, 0, 0)}
	b.key(0.0, _sk(st, from, Vector3(0.42, 1.63, -0.22), Vector3(0.55, 0.74, 0.39), Vector3(-0.3, -0.25, 0.92)))
	b.key(w * 0.2, _sk(st, _merge(from, {"@Hips": Vector3(0, -0.2, -0.04), "Spine": Vector3(-10, -6, 0), "^Body": Vector3(1.05, 0.94, 1.05)}),
		Vector3(0.36, 1.6, -0.12), Vector3(0.4, 0.75, 0.52), Vector3(0, 0.6, -0.8)), OUT)
	# Rise: both hands lift the sword overhead, body stretches tall and leans back.
	var raised := {"@Hips": Vector3(0, -0.02, 0.06), "Hips": Vector3(0, -4, 0), "Spine": Vector3(10, -2, 0),
		"Chest": Vector3(8, -4, 0), "Neck": Vector3(-4, 0, 0), "Head": Vector3(-6, 0, 0),
		"LegL": Vector3(10, 0, -6), "ShinL": Vector3(-12, 0, 0), "FootL": Vector3(0, 0, 0),
		"LegR": Vector3(-10, 0, 6), "ShinR": Vector3(-14, 0, 0), "FootR": Vector3(10, 0, 0), "^Body": Vector3(0.94, 1.08, 0.94)}
	b.key(w * 0.72, _sk(st, raised, Vector3(0.1, 2.05, 0.08), Vector3(0.05, 0.35, 0.94), Vector3(0, 0.94, -0.35), true), INOUT)
	b.key(w * 0.86, _sk(st, _merge(raised, {"Spine": Vector3(12, -2, 0), "@Hips": Vector3(0, -0.01, 0.07)}),
		Vector3(0.1, 2.06, 0.11), Vector3(0.05, 0.3, 0.95), Vector3(0, 0.95, -0.3), true), L)
	var chop := {"@Hips": Vector3(0, -0.26, -0.12), "Hips": Vector3(0, 0, 0), "Spine": Vector3(-28, 0, 0),
		"Chest": Vector3(-16, 0, 0), "Neck": Vector3(10, 0, 0), "Head": Vector3(14, 0, 0),
		"LegL": Vector3(50, 0, -6), "ShinL": Vector3(-62, 0, 0), "FootL": Vector3(8, 0, 0),
		"LegR": Vector3(-34, 0, 6), "ShinR": Vector3(-44, 0, 0), "FootR": Vector3(42, 0, 0), "^Body": Vector3(1.08, 0.9, 1.08)}
	b.key(w, _sk(st, _merge(raised, {"Spine": Vector3(-6, 0, 0), "Chest": Vector3(-4, 0, 0), "@Hips": Vector3(0, -0.12, -0.04), "^Body": Vector3.ONE}),
		Vector3(0.08, 1.95, -0.38), Vector3(0.02, 0.8, -0.6), Vector3(0, 0.6, 0.8), true), IN)
	b.key(w + a * 0.5, _sk(st, chop, Vector3(0.05, 1.3, -0.72), Vector3(0.0, 0.05, -1.0), Vector3(0, -1, 0), true), L)
	b.key(w + a, _sk(st, chop, Vector3(0.03, 0.95, -0.66), Vector3(0.0, -0.7, -0.71), Vector3(0, -0.71, 0.7), true), L)
	var down := _sk(st, chop, Vector3(0.03, 0.78, -0.62), Vector3(0.0, -0.92, -0.38), Vector3(0, -0.38, 0.92), true)
	b.key(w + a + r * 0.18, down, OUT)
	b.key(w + a + r * 0.45, _sk(st, _merge(chop, {"@Hips": Vector3(0, -0.24, -0.11), "^Body": Vector3.ONE}),
		Vector3(0.03, 0.8, -0.62), Vector3(0.0, -0.9, -0.42), Vector3(0, -0.42, 0.9), true), L)
	b.key(w + a + r, st, INOUT)
	_attack_events(b, w, a)
	lib.add_animation(&"light_3", b.build())


## Heavy: two-handed charged sweep. Windup draws the blade back low to the right with a
## deep coil, the charge holds it (trembling), the release sweeps right-to-left.
func _heavy(lib: AnimationLibrary, st: Dictionary) -> void:
	var tm := _attack_times(&"heavy_release", 0.55, 0.14, 0.66)
	var a: float = tm[1]
	var r: float = tm[2]
	var w: float = tm[0]
	var pole := Vector3(0.6, -0.6, 0.2)
	var coil := {"@Hips": Vector3(0, -0.19, 0.06), "Hips": Vector3(0, -42, 0), "Spine": Vector3(-6, -26, 0),
		"Chest": Vector3(0, -40, 8), "Neck": Vector3(4, 26, 0), "Head": Vector3(6, 22, 0),
		"LegL": Vector3(30, 0, -10), "ShinL": Vector3(-30, 0, 0), "FootL": Vector3(0, 0, 0),
		"LegR": Vector3(-24, 0, 8), "ShinR": Vector3(-42, 0, 0), "FootR": Vector3(40, 0, 0), "^Body": Vector3(1.05, 0.93, 1.05)}
	var cocked := _sk(st, coil, Vector3(0.46, 1.02, 0.32), Vector3(0.5, 0.1, 0.86), Vector3(-0.86, 0.0, -0.5), true, pole)
	var wb := AnimBuilder.new(self, &"heavy_windup", w)
	wb.key(0.0, st)
	wb.key(w * 0.2, _sk(st, {"@Hips": Vector3(0, -0.13, 0.02), "Hips": Vector3(0, -16, 0), "^Body": Vector3(1.03, 0.96, 1.03)},
		Vector3(0.4, 1.0, -0.1), Vector3(0.3, -0.1, 0.95), Vector3(-0.9, 0, -0.3)), OUT)
	wb.key(w * 0.8, _sk(st, _merge(coil, {"Chest": Vector3(0, -44, 8)}), Vector3(0.48, 1.03, 0.36), Vector3(0.52, 0.1, 0.85), Vector3(-0.85, 0.0, -0.52), true, pole), INOUT)
	wb.key(w, cocked, INOUT)
	lib.add_animation(&"heavy_windup", wb.build())

	var cb := AnimBuilder.new(self, &"heavy_charge", 0.2, true)
	cb.key(0.0, cocked)
	cb.key(0.1, _sk(st, _merge(coil, {"@Hips": Vector3(0, -0.2, 0.065), "Chest": Vector3(1, -42, 9), "^Body": Vector3(1.06, 0.92, 1.06)}),
		Vector3(0.47, 1.0, 0.34), Vector3(0.51, 0.11, 0.85), Vector3(-0.86, 0.0, -0.5), true, pole))
	lib.add_animation(&"heavy_charge", cb.build())

	var pre := 0.03
	var sweep := {"@Hips": Vector3(0, -0.22, -0.12), "Hips": Vector3(0, 30, 0), "Spine": Vector3(-16, 22, 0),
		"Chest": Vector3(-8, 48, -8), "Neck": Vector3(6, -24, 0), "Head": Vector3(8, -20, 0),
		"LegL": Vector3(50, 0, -8), "ShinL": Vector3(-50, 0, 0), "FootL": Vector3(4, 0, 0),
		"LegR": Vector3(-34, 0, 8), "ShinR": Vector3(-38, 0, 0), "FootR": Vector3(40, 0, 0), "^Body": Vector3(0.96, 1.05, 0.96)}
	var rb := AnimBuilder.new(self, &"heavy_release", pre + a + r)
	rb.key(0.0, cocked)
	rb.key(pre + a * 0.5, _sk(st, sweep, Vector3(0.05, 1.15, -0.68), Vector3(-0.4, 0.02, -0.92), Vector3(-0.92, 0.0, 0.4), true, pole), IN)
	rb.key(pre + a, _sk(st, sweep, Vector3(-0.36, 1.1, -0.46), Vector3(-0.97, 0.0, -0.2), Vector3(-0.2, 0.0, 0.98), true, pole), L)
	var follow := _merge(sweep, {"Chest": Vector3(-8, 56, -8), "Hips": Vector3(0, 36, 0)})
	rb.key(pre + a + r * 0.22, _sk(st, follow, Vector3(-0.46, 1.04, -0.1), Vector3(-0.6, -0.1, 0.79), Vector3(0.79, 0.0, 0.6), true, pole), OUT)
	rb.key(pre + a + r * 0.48, _sk(st, _merge(follow, {"@Hips": Vector3(0, -0.2, -0.11), "^Body": Vector3.ONE}),
		Vector3(-0.45, 1.03, -0.12), Vector3(-0.6, -0.12, 0.79), Vector3(0.79, 0.0, 0.6), true, pole), L)
	rb.key(pre + a + r, st, INOUT)
	rb.event(0.017, &"swing")
	rb.event(0.017, &"trail_on")
	# The box is in front of the hero: switch it on when the sweep crosses the front.
	rb.event(pre + a * 0.35, &"hitbox_on")
	rb.event(pre + a + 0.02, &"hitbox_off")
	lib.add_animation(&"heavy_release", rb.build())


## Roll: drop and push off, tucked forward roll, then the get-up - a body that has to
## gather itself before it can act again. Sword held back along the forearm.
func _dodge(lib: AnimationLibrary, st: Dictionary) -> void:
	var length := float(_timing(&"dodge").get("length", 0.62))
	var b := AnimBuilder.new(self, &"dodge", length)
	var tucked_sword := sword(Vector3(0.18, -0.12, -0.22), Vector3(0.12, -0.25, 0.96), Vector3(0, -1, 0))
	var tuck := _merge({"Spine": Vector3(-50, 0, 0), "Chest": Vector3(-30, 0, 0), "Neck": Vector3(-20, 0, 0), "Head": Vector3(-10, 0, 0),
		"ArmL": AnimBuilder.limb(0, 110), "ForearmL": Vector3(120, 0, 0),
		"LegR": Vector3(110, 0, 0), "ShinR": Vector3(-130, 0, 0), "FootR": Vector3(20, 0, 0),
		"LegL": Vector3(105, 0, 0), "ShinL": Vector3(-130, 0, 0), "FootL": Vector3(20, 0, 0)}, tucked_sword)
	b.key(0.0, st)
	# Drop and push off.
	b.key(length * 0.1, _merge(tucked_sword, {"@Hips": Vector3(0, -0.3, -0.05), "Hips": Vector3(-20, 0, 0), "Spine": Vector3(-38, 0, 0),
		"Chest": Vector3(-20, 0, 0), "LegL": Vector3(70, 0, 0), "ShinL": Vector3(-90, 0, 0), "LegR": Vector3(-10, 0, 0), "ShinR": Vector3(-40, 0, 0),
		"^Body": Vector3(1.08, 0.9, 1.08)}), OUT)
	b.key(length * 0.22, _merge(tuck, {"@Hips": Vector3(0, -0.45, 0), "Hips": Vector3(-90, 0, 0), "^Body": Vector3(0.95, 1.06, 0.95)}), L)
	b.key(length * 0.42, _merge(tuck, {"@Hips": Vector3(0, -0.55, 0), "Hips": Vector3(-210, 0, 0), "^Body": Vector3.ONE}), L)
	b.key(length * 0.58, _merge(tuck, {"@Hips": Vector3(0, -0.45, 0), "Hips": Vector3(-310, 0, 0)}), L)
	# Land in a crouch on one knee-ish, then stand up into the guard.
	var crouch := _merge(st, {"@Hips": Vector3(0, -0.36, 0.0), "Hips": Vector3(-358, -8, 0), "Spine": Vector3(-26, 0, 0),
		"Chest": Vector3(-14, 0, 0), "Head": Vector3(10, 0, 0),
		"LegL": Vector3(70, 0, 8), "ShinL": Vector3(-100, 0, 0), "FootL": Vector3(30, 0, 0),
		"LegR": Vector3(10, 0, -6), "ShinR": Vector3(-110, 0, 0), "FootR": Vector3(60, 0, 0), "^Body": Vector3(1.07, 0.92, 1.07)})
	b.key(length * 0.7, _merge(crouch, tucked_sword), OUT)
	b.key(length, _merge(st, {"Hips": Vector3(-360, -14, 0)}), INOUT)
	b.event(0.017, &"dodge_start")
	b.event(length * 0.68, &"footstep")
	lib.add_animation(&"dodge", b.build())


func _hit(lib: AnimationLibrary, st: Dictionary) -> void:
	var d := float(_timing(&"hit").get("length", 0.36))
	var b := AnimBuilder.new(self, &"hit", d)
	b.key(0.0, st)
	b.key(d * 0.15, _merge({"@Hips": Vector3(0, -0.13, 0.08), "Spine": Vector3(16, 0, 4), "Chest": Vector3(14, -12, 0), "Head": Vector3(22, 8, 0),
		"ArmL": AnimBuilder.limb(-80, 55), "ForearmL": Vector3(70, 0, 0), "^Body": Vector3(1.05, 0.94, 1.05)},
		sword(Vector3(0.3, -0.12, -0.12), Vector3(0.2, 0.3, -0.93), Vector3(0, -1, 0))), SNAP)
	b.key(d * 0.45, {"@Hips": Vector3(0, -0.12, 0.05), "Spine": Vector3(8, 0, 2)}, OUT)
	b.key(d, st, INOUT)
	lib.add_animation(&"hit", b.build())

	var dh := float(_timing(&"hit_heavy").get("length", 0.6))
	var bh := AnimBuilder.new(self, &"hit_heavy", dh)
	bh.key(0.0, st)
	bh.key(dh * 0.14, _merge({"@Hips": Vector3(0, -0.24, 0.14), "Hips": Vector3(18, 0, 0), "Spine": Vector3(26, 0, 6), "Chest": Vector3(18, -14, 0), "Head": Vector3(28, 10, 0),
		"ArmL": AnimBuilder.limb(-100, 75), "ForearmL": Vector3(30, 0, 0),
		"LegL": Vector3(40, 0, 10), "ShinL": Vector3(-60, 0, 0), "LegR": Vector3(-10, 0, 0), "ShinR": Vector3(-70, 0, 0),
		"^Body": Vector3(1.07, 0.91, 1.07)}, sword(Vector3(0.36, 0.0, -0.05), Vector3(0.35, 0.6, -0.72), Vector3(0, -1, 0))), SNAP)
	bh.key(dh * 0.55, {"@Hips": Vector3(0, -0.2, 0.06), "Hips": Vector3(6, 0, 0), "Spine": Vector3(-20, 0, 0), "Head": Vector3(10, 0, 0)}, INOUT)
	bh.key(dh, st, INOUT)
	lib.add_animation(&"hit_heavy", bh.build())


func _death(lib: AnimationLibrary, st: Dictionary) -> void:
	var b := AnimBuilder.new(self, &"death", 1.6)
	b.key(0.0, st)
	b.key(0.25, {"@Hips": Vector3(0, -0.1, 0.1), "Spine": Vector3(20, 0, 8), "Head": Vector3(30, 0, 0),
		"ArmR": AnimBuilder.limb(90, 60), "ArmL": AnimBuilder.limb(-90, 60)}, SNAP)
	b.key(0.7, {"@Hips": Vector3(0, -0.5, 0), "Hips": Vector3(-10, 0, 0), "Spine": Vector3(-30, 0, 0), "Chest": Vector3(-20, 0, 0), "Head": Vector3(-20, 0, 0),
		"LegR": Vector3(80, 0, 0), "ShinR": Vector3(-120, 0, 0), "LegL": Vector3(70, 0, 10), "ShinL": Vector3(-120, 0, 0),
		"ArmR": AnimBuilder.limb(20, 30), "ArmL": AnimBuilder.limb(-20, 30)}, IN)
	b.key(1.2, {"@Hips": Vector3(0, -0.78, -0.3), "Hips": Vector3(-82, 0, 6), "Spine": Vector3(-5, 0, 0), "Chest": Vector3(0, 0, 0), "Head": Vector3(10, 30, 0),
		"LegR": Vector3(10, 0, 0), "ShinR": Vector3(-20, 0, 0), "LegL": Vector3(14, 0, 10), "ShinL": Vector3(-30, 0, 0),
		"ArmR": AnimBuilder.limb(60, 150), "ForearmR": Vector3(20, 0, 0), "ArmL": AnimBuilder.limb(-60, 120), "ForearmL": Vector3(20, 0, 0),
		"^Body": Vector3(1.0, 1.0, 1.0)}, IN)
	b.key(1.32, {"@Hips": Vector3(0, -0.74, -0.32), "^Body": Vector3(1.04, 0.95, 1.04)}, OUT)
	b.key(1.6, {"@Hips": Vector3(0, -0.78, -0.3), "^Body": Vector3.ONE}, INOUT)
	b.event(1.2, &"body_fall")
	lib.add_animation(&"death", b.build())


func _heal(lib: AnimationLibrary, st: Dictionary) -> void:
	var t := _timing(&"heal")
	var d := float(t.get("length", 0.7))
	var apply := float(t.get("apply", 0.45))
	var b := AnimBuilder.new(self, &"heal", d)
	var raise := {"ArmL": AnimBuilder.limb(-10, 150), "ForearmL": Vector3(30, 0, 0), "HandL": Vector3(-20, 0, 0),
		"Head": Vector3(-20, 0, 0), "Spine": Vector3(6, 0, 0), "Chest": Vector3(6, 0, 0)}
	b.key(0.0, st)
	b.key(apply * 0.7, raise, OUT)
	b.key(apply, _merge(raise, {"@Hips": Vector3(0, -0.06, 0), "^Body": Vector3(0.97, 1.05, 0.97)}), OUT)
	b.key(d, _merge(st, {"^Body": Vector3.ONE}), INOUT)
	b.event(0.017, &"heal_start")
	b.event(apply, &"heal_apply")
	lib.add_animation(&"heal", b.build())


func _cast(lib: AnimationLibrary, st: Dictionary) -> void:
	var tm := _attack_times(&"cast", 0.3, 0.06, 0.42)
	var w: float = tm[0]
	var a: float = tm[1]
	var r: float = tm[2]
	var b := AnimBuilder.new(self, &"cast", w + a + r)
	b.key(0.0, st)
	b.key(w * 0.8, _merge({"Hips": Vector3(0, 20, 0), "Chest": Vector3(0, 30, 0), "ArmL": AnimBuilder.limb(-60, 80), "ForearmL": Vector3(90, 0, 0),
		"@Hips": Vector3(0, -0.13, 0.03)}, sword(Vector3(0.3, -0.2, 0.0), Vector3(0.2, -0.4, 0.89), Vector3(0, -1, 0))), INOUT)
	b.key(w + a, _merge({"Hips": Vector3(0, -10, 0), "Chest": Vector3(-6, -14, 0), "ArmL": AnimBuilder.limb(-5, 92), "ForearmL": Vector3(0, 0, 0), "HandL": Vector3(-60, 0, 0),
		"@Hips": Vector3(0, -0.15, -0.03), "^Body": Vector3(0.97, 1.03, 0.97),
		"LegL": Vector3(30, 0, 6), "ShinL": Vector3(-26, 0, 0)}, sword(Vector3(0.32, -0.22, 0.05), Vector3(0.25, -0.35, 0.9), Vector3(0, -1, 0))), SNAP)
	b.key(w + a + r * 0.4, {"@Hips": Vector3(0, -0.14, -0.02)}, OUT)
	b.key(w + a + r, st, INOUT)
	b.event(maxf(w, 0.017), &"cast_fire")
	lib.add_animation(&"cast", b.build())


func _rest(lib: AnimationLibrary, st: Dictionary) -> void:
	var b := AnimBuilder.new(self, &"rest", 0.9)
	b.key(0.0, st)
	b.key(0.6, _merge({"@Hips": Vector3(0, -0.42, 0.05), "Hips": Vector3(0, 0, 0), "Spine": Vector3(-10, 0, 0), "Chest": Vector3(-8, 0, 0), "Head": Vector3(25, 0, 0),
		"LegL": Vector3(85, 0, 4), "ShinL": Vector3(-90, 0, 0), "FootL": Vector3(5, 0, 0),
		"LegR": Vector3(-5, 0, -4), "ShinR": Vector3(-95, 0, 0), "FootR": Vector3(10, 0, 0),
		"ArmL": AnimBuilder.limb(-10, 40), "ForearmL": Vector3(80, 0, 0)},
		sword(Vector3(0.18, -0.36, -0.36), Vector3(0.0, -0.98, -0.2), Vector3(0, 0, -1))), INOUT)
	lib.add_animation(&"rest", b.build())


func _grabbed(lib: AnimationLibrary, st: Dictionary) -> void:
	var b := AnimBuilder.new(self, &"grabbed", 0.4, true)
	var held := {"@Hips": Vector3(0, 0.12, 0), "Spine": Vector3(10, 0, 0), "Head": Vector3(20, 0, 0),
		"ArmR": AnimBuilder.limb(30, 90, -20), "ForearmR": Vector3(80, 0, 0), "ArmL": AnimBuilder.limb(-30, 90), "ForearmL": Vector3(80, 0, 0),
		"LegR": Vector3(20, 0, 0), "ShinR": Vector3(-40, 0, 0), "LegL": Vector3(-10, 0, 0), "ShinL": Vector3(-30, 0, 0)}
	b.key(0.0, _merge(st, held))
	b.key(0.2, {"Spine": Vector3(16, 12, 6), "LegR": Vector3(-10, 0, 0), "LegL": Vector3(25, 0, 0), "ArmR": AnimBuilder.limb(40, 100, -20)})
	lib.add_animation(&"grabbed", b.build())


func _interact(lib: AnimationLibrary, st: Dictionary) -> void:
	var b := AnimBuilder.new(self, &"interact", 0.8)
	b.key(0.0, st)
	b.key(0.25, {"Spine": Vector3(-20, 0, 0), "ArmL": AnimBuilder.limb(-10, 80), "ForearmL": Vector3(10, 0, 0), "@Hips": Vector3(0, -0.14, 0)}, OUT)
	b.key(0.5, {"Spine": Vector3(8, 0, 0), "ArmL": AnimBuilder.limb(-10, 40), "ForearmL": Vector3(60, 0, 0), "@Hips": Vector3(0, -0.18, 0.08)}, SNAP)
	b.key(0.8, st, INOUT)
	b.event(0.45, &"interact_point")
	lib.add_animation(&"interact", b.build())
