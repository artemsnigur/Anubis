class_name HeroRig
extends PlaceholderRig
## The awakened ushabti: turquoise faience figurine with gold veins, striped lapis wig,
## gold usekh collar and a bronze khopesh. Clips are generated from the player's AttackData.

const L := AnimBuilder.LINEAR
const IN := AnimBuilder.IN
const OUT := AnimBuilder.OUT
const SNAP := AnimBuilder.SNAP
const INOUT := AnimBuilder.INOUT
const BACK := AnimBuilder.BACK
const GAIT_LENGTH := 0.6


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
	part("Hips", box(Vector3(0.1, 0.3, 0.03)), gold, Vector3(0, -0.12, -0.13))

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
	part("Head", box(Vector3(0.08, 0.26, 0.07)), lapis, Vector3(0.12, -0.02, -0.06), Vector3(0, 0, -4))
	part("Head", box(Vector3(0.08, 0.26, 0.07)), lapis, Vector3(-0.12, -0.02, -0.06), Vector3(0, 0, 4))
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

	# Khopesh in the right hand: grip along -Y, blade hooks forward.
	var socket := add_socket(&"weapon_r", "HandR", Vector3(0, -0.06, -0.01), Vector3(82, 0, 0))
	var grip := MeshInstance3D.new()
	grip.mesh = cylinder(0.022, 0.022, 0.18, 8)
	grip.material_override = Mats.get_mat(&"wood")
	grip.position = Vector3(0, -0.02, 0)
	socket.add_child(grip)
	var pommel := MeshInstance3D.new()
	pommel.mesh = sphere(0.035, -1.0, 8)
	pommel.material_override = gold
	pommel.position = Vector3(0, 0.08, 0)
	socket.add_child(pommel)
	var blade := MeshInstance3D.new()
	blade.mesh = cached_mesh("khopesh", KhopeshMesh.build)
	blade.material_override = Mats.get_mat(&"bronze")
	socket.add_child(blade)
	var tb := Node3D.new()
	tb.name = "TrailBase"
	tb.position = Vector3(0, -0.16, 0)
	socket.add_child(tb)
	sockets[&"trail_base"] = tb
	var tt := Node3D.new()
	tt.name = "TrailTip"
	tt.position = Vector3(0, -0.66, -0.3)
	socket.add_child(tt)
	sockets[&"trail_tip"] = tt
	add_socket(&"hand_l", "HandL", Vector3(0, -0.08, -0.04))
	add_socket(&"chest", "Chest", Vector3(0, 0.15, -0.15))
	add_socket(&"head", "Head", Vector3(0, 0.15, -0.1))


# --- poses ------------------------------------------------------------------------

func _stance() -> Dictionary:
	return {
		"@Hips": Vector3(0, -0.05, 0), "Hips": Vector3(0, -12, 0),
		"Spine": Vector3(-6, 6, 0), "Chest": Vector3(-4, 4, 0), "Neck": Vector3(2, 0, 0), "Head": Vector3(4, 2, 0),
		"ArmR": AnimBuilder.limb(30, 28, -20), "ForearmR": Vector3(62, 0, 0), "HandR": Vector3(0, 0, 0),
		"ArmL": AnimBuilder.limb(-30, 24), "ForearmL": Vector3(45, 0, 0), "HandL": Vector3(0, 0, 0),
		"LegR": Vector3(-14, 0, -4), "ShinR": Vector3(-22, 0, 0), "FootR": Vector3(22, 0, 0),
		"LegL": Vector3(18, 0, 6), "ShinL": Vector3(-14, 0, 0), "FootL": Vector3(-4, 0, 0),
		"^Body": Vector3.ONE,
	}


func _merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var r := a.duplicate()
	for k: Variant in b:
		r[k] = b[k]
	return r


func _build_clips(lib: AnimationLibrary) -> void:
	var st := _stance()
	_idle(lib, st)
	# Same cycle length for walk and run so the synced blend keeps the feet in phase;
	# the animator rescales playback from the stride so the feet stay planted.
	_gait(lib, &"walk", GAIT_LENGTH, 1.4, 0.57, 0.1, -0.02, 0.02, 0.0)
	_gait(lib, &"run", GAIT_LENGTH, 3.0, 0.25, 0.3, -0.04, 0.04, 1.0)
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
	var b := AnimBuilder.new(self, &"idle", 2.0, true)
	b.key(0.0, st)
	b.key(1.0, {"@Hips": Vector3(0, -0.065, 0), "Chest": Vector3(-1, 5, 0), "ArmR": AnimBuilder.limb(32, 31, -20),
		"ArmL": AnimBuilder.limb(-32, 27), "Head": Vector3(6, 0, 0), "ShinR": Vector3(-26, 0, 0), "ShinL": Vector3(-18, 0, 0)})
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
		var lean := -5.0 - 10.0 * k
		# No hip yaw: it would swing the planted foot. The twist lives in spine / chest.
		pose["Hips"] = Vector3.ZERO
		pose["Spine"] = Vector3(lean, (3.0 + 5.0 * k) * swing, 0)
		pose["Chest"] = Vector3(-2.0 * k, -(9.0 * k + 6.0) * swing, 0)
		pose["Neck"] = Vector3(-lean * 0.45, 0, 0)
		pose["Head"] = Vector3(-lean * 0.3, (4.0 * k + 2.0) * swing, 0)
		pose["ArmR"] = AnimBuilder.limb(28.0 - 14.0 * swing, 24.0 + 8.0 * k - 10.0 * swing, -20.0)
		pose["ForearmR"] = Vector3(55.0 + 15.0 * k, 0, 0)
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
	b.event(maxf(w * 0.4, 0.017), &"swing")
	b.event(maxf(w, 0.017), &"hitbox_on")
	b.event(w + a, &"hitbox_off")


func _light_1(lib: AnimationLibrary, st: Dictionary) -> void:
	var tm := _attack_times(&"light_1", 0.1, 0.08, 0.2)
	var w: float = tm[0]
	var a: float = tm[1]
	var r: float = tm[2]
	var b := AnimBuilder.new(self, &"light_1", w + a + r)
	b.key(0.0, st)
	b.key(w, {"@Hips": Vector3(0, -0.08, 0), "Hips": Vector3(0, -24, 0), "Spine": Vector3(-8, -18, 0), "Chest": Vector3(-4, -30, 4),
		"ArmR": AnimBuilder.limb(115, 82, -40), "ForearmR": Vector3(40, 0, 0), "HandR": Vector3(0, 0, -20),
		"ArmL": AnimBuilder.limb(-50, 45), "ForearmL": Vector3(60, 0, 0),
		"LegL": Vector3(26, 0, 6), "ShinL": Vector3(-18, 0, 0), "^Body": Vector3(1.03, 0.96, 1.03)}, OUT)
	b.key(w + a, {"@Hips": Vector3(0, -0.11, 0), "Hips": Vector3(0, 18, 0), "Spine": Vector3(-14, 16, 0), "Chest": Vector3(-6, 36, -4),
		"ArmR": AnimBuilder.limb(-55, 84, 10), "ForearmR": Vector3(8, 0, 0), "HandR": Vector3(0, 0, 10),
		"ArmL": AnimBuilder.limb(-120, 35), "ForearmL": Vector3(30, 0, 0),
		"LegL": Vector3(34, 0, 6), "ShinL": Vector3(-26, 0, 0), "^Body": Vector3(0.97, 1.04, 0.97)}, SNAP)
	b.key(w + a + r * 0.35, {"Chest": Vector3(-6, 44, -4), "ArmR": AnimBuilder.limb(-72, 76, 10), "^Body": Vector3.ONE}, OUT)
	b.key(w + a + r, st, INOUT)
	_attack_events(b, w, a)
	lib.add_animation(&"light_1", b.build())


func _light_2(lib: AnimationLibrary, st: Dictionary) -> void:
	var tm := _attack_times(&"light_2", 0.1, 0.08, 0.2)
	var w: float = tm[0]
	var a: float = tm[1]
	var r: float = tm[2]
	var b := AnimBuilder.new(self, &"light_2", w + a + r)
	var from := {"@Hips": Vector3(0, -0.1, 0), "Hips": Vector3(0, 18, 0), "Spine": Vector3(-12, 14, 0), "Chest": Vector3(-6, 36, -4),
		"ArmR": AnimBuilder.limb(-62, 78, 10), "ForearmR": Vector3(20, 0, 0), "HandR": Vector3(0, 0, 10),
		"ArmL": AnimBuilder.limb(-110, 35), "ForearmL": Vector3(35, 0, 0), "LegL": Vector3(30, 0, 6), "ShinL": Vector3(-24, 0, 0)}
	b.key(0.0, _merge(st, from))
	b.key(w, {"Chest": Vector3(-8, 44, -6), "ArmR": AnimBuilder.limb(-80, 70, 30), "ForearmR": Vector3(70, 0, 0),
		"HandR": Vector3(0, 0, 30), "^Body": Vector3(1.03, 0.97, 1.03)}, OUT)
	b.key(w + a, {"@Hips": Vector3(0, -0.07, 0), "Hips": Vector3(0, -26, 0), "Spine": Vector3(-10, -16, 0), "Chest": Vector3(-2, -36, 6),
		"ArmR": AnimBuilder.limb(105, 98, -30), "ForearmR": Vector3(6, 0, 0), "HandR": Vector3(0, 0, -15),
		"ArmL": AnimBuilder.limb(-30, 40), "ForearmL": Vector3(60, 0, 0),
		"LegR": Vector3(-24, 0, -6), "ShinR": Vector3(-24, 0, 0), "^Body": Vector3(0.97, 1.04, 0.97)}, SNAP)
	b.key(w + a + r * 0.35, {"Chest": Vector3(-2, -44, 6), "ArmR": AnimBuilder.limb(122, 102, -30), "^Body": Vector3.ONE}, OUT)
	b.key(w + a + r, st, INOUT)
	_attack_events(b, w, a)
	lib.add_animation(&"light_2", b.build())


func _light_3(lib: AnimationLibrary, st: Dictionary) -> void:
	var tm := _attack_times(&"light_3", 0.16, 0.08, 0.35)
	var w: float = tm[0]
	var a: float = tm[1]
	var r: float = tm[2]
	var b := AnimBuilder.new(self, &"light_3", w + a + r)
	var from := {"@Hips": Vector3(0, -0.07, 0), "Hips": Vector3(0, -26, 0), "Spine": Vector3(-10, -16, 0), "Chest": Vector3(-2, -36, 6),
		"ArmR": AnimBuilder.limb(110, 96, -30), "ForearmR": Vector3(10, 0, 0)}
	b.key(0.0, _merge(st, from))
	# Rise: blade overhead, body stretched.
	b.key(w, {"@Hips": Vector3(0, 0.02, 0), "Hips": Vector3(0, -6, 0), "Spine": Vector3(12, -4, 0), "Chest": Vector3(8, -6, 0), "Head": Vector3(-6, 0, 0),
		"ArmR": AnimBuilder.limb(15, 168, 0), "ForearmR": Vector3(70, 0, 0), "HandR": Vector3(-20, 0, 0),
		"ArmL": AnimBuilder.limb(-20, 140), "ForearmL": Vector3(40, 0, 0),
		"LegL": Vector3(10, 0, 4), "ShinL": Vector3(-6, 0, 0), "LegR": Vector3(-8, 0, -4), "ShinR": Vector3(-8, 0, 0),
		"^Body": Vector3(0.94, 1.08, 0.94)}, OUT)
	# Slam down in front: deep lunge, squash.
	b.key(w + a, {"@Hips": Vector3(0, -0.2, 0), "Hips": Vector3(0, 0, 0), "Spine": Vector3(-26, 0, 0), "Chest": Vector3(-16, 0, 0), "Head": Vector3(14, 0, 0),
		"ArmR": AnimBuilder.limb(0, 70, 0), "ForearmR": Vector3(8, 0, 0), "HandR": Vector3(10, 0, 0),
		"ArmL": AnimBuilder.limb(-35, 50), "ForearmL": Vector3(30, 0, 0),
		"LegL": Vector3(48, 0, 6), "ShinL": Vector3(-50, 0, 0), "FootL": Vector3(0, 0, 0),
		"LegR": Vector3(-30, 0, -6), "ShinR": Vector3(-40, 0, 0), "FootR": Vector3(40, 0, 0),
		"^Body": Vector3(1.08, 0.9, 1.08)}, SNAP)
	b.key(w + a + r * 0.45, {"^Body": Vector3.ONE, "@Hips": Vector3(0, -0.17, 0)}, OUT)
	b.key(w + a + r, st, INOUT)
	_attack_events(b, w, a)
	lib.add_animation(&"light_3", b.build())


func _heavy(lib: AnimationLibrary, st: Dictionary) -> void:
	var tm := _attack_times(&"heavy_release", 0.4, 0.12, 0.45)
	var w: float = tm[0]
	var a: float = tm[1]
	var r: float = tm[2]
	var cocked := {"@Hips": Vector3(0, -0.13, 0), "Hips": Vector3(0, -40, 0), "Spine": Vector3(-4, -26, 0), "Chest": Vector3(2, -44, 8), "Head": Vector3(4, 30, 0),
		"ArmR": AnimBuilder.limb(150, 112, -40), "ForearmR": Vector3(55, 0, 0), "HandR": Vector3(0, 0, -25),
		"ArmL": AnimBuilder.limb(-40, 70), "ForearmL": Vector3(70, 0, 0),
		"LegL": Vector3(34, 0, 10), "ShinL": Vector3(-34, 0, 0), "FootL": Vector3(0, 0, 0),
		"LegR": Vector3(-26, 0, -8), "ShinR": Vector3(-30, 0, 0), "FootR": Vector3(34, 0, 0),
		"^Body": Vector3(1.05, 0.93, 1.05)}
	var wb := AnimBuilder.new(self, &"heavy_windup", w)
	wb.key(0.0, st)
	wb.key(w * 0.75, _merge(cocked, {"Chest": Vector3(2, -50, 8), "ArmR": AnimBuilder.limb(158, 115, -40)}), OUT)
	wb.key(w, cocked, INOUT)
	lib.add_animation(&"heavy_windup", wb.build())

	var cb := AnimBuilder.new(self, &"heavy_charge", 0.24, true)
	cb.key(0.0, cocked)
	cb.key(0.12, {"@Hips": Vector3(0, -0.145, 0), "Chest": Vector3(3, -47, 9), "ArmR": AnimBuilder.limb(153, 114, -42), "^Body": Vector3(1.06, 0.92, 1.06)})
	lib.add_animation(&"heavy_charge", cb.build())

	var pre := 0.03
	var rb := AnimBuilder.new(self, &"heavy_release", pre + a + r)
	rb.key(0.0, cocked)
	rb.key(pre + a, {"@Hips": Vector3(0, -0.16, 0), "Hips": Vector3(0, 30, 0), "Spine": Vector3(-18, 22, 0), "Chest": Vector3(-8, 52, -8), "Head": Vector3(8, -20, 0),
		"ArmR": AnimBuilder.limb(-70, 80, 10), "ForearmR": Vector3(4, 0, 0), "HandR": Vector3(0, 0, 15),
		"ArmL": AnimBuilder.limb(-140, 40), "ForearmL": Vector3(25, 0, 0),
		"LegL": Vector3(50, 0, 8), "ShinL": Vector3(-46, 0, 0), "LegR": Vector3(-34, 0, -8), "ShinR": Vector3(-36, 0, 0),
		"^Body": Vector3(0.95, 1.06, 0.95)}, SNAP)
	rb.key(pre + a + r * 0.4, {"Chest": Vector3(-8, 60, -8), "ArmR": AnimBuilder.limb(-90, 72, 10), "^Body": Vector3.ONE}, OUT)
	rb.key(pre + a + r, st, INOUT)
	rb.event(0.017, &"swing")
	rb.event(pre, &"hitbox_on")
	rb.event(pre + a, &"hitbox_off")
	lib.add_animation(&"heavy_release", rb.build())


func _dodge(lib: AnimationLibrary, st: Dictionary) -> void:
	var length := float(_timing(&"dodge").get("length", 0.35))
	var b := AnimBuilder.new(self, &"dodge", length)
	var tuck := {"Spine": Vector3(-50, 0, 0), "Chest": Vector3(-30, 0, 0), "Neck": Vector3(-20, 0, 0), "Head": Vector3(-10, 0, 0),
		"ArmR": AnimBuilder.limb(0, 120, -20), "ForearmR": Vector3(110, 0, 0),
		"ArmL": AnimBuilder.limb(0, 110), "ForearmL": Vector3(120, 0, 0),
		"LegR": Vector3(110, 0, 0), "ShinR": Vector3(-130, 0, 0), "FootR": Vector3(20, 0, 0),
		"LegL": Vector3(105, 0, 0), "ShinL": Vector3(-130, 0, 0), "FootL": Vector3(20, 0, 0)}
	b.key(0.0, _merge(st, {"^Body": Vector3(1.0, 1.0, 1.0)}))
	b.key(length * 0.12, _merge(tuck, {"@Hips": Vector3(0, -0.35, 0), "Hips": Vector3(-40, 0, 0), "^Body": Vector3(0.9, 1.1, 0.9)}), OUT)
	b.key(length * 0.36, _merge(tuck, {"@Hips": Vector3(0, -0.52, 0), "Hips": Vector3(-160, 0, 0), "^Body": Vector3(1.0, 1.0, 1.0)}), L)
	b.key(length * 0.6, _merge(tuck, {"@Hips": Vector3(0, -0.5, 0), "Hips": Vector3(-280, 0, 0)}), L)
	b.key(length * 0.78, _merge({"@Hips": Vector3(0, -0.22, 0), "Hips": Vector3(-345, 0, 0), "^Body": Vector3(1.05, 0.94, 1.05)},
		{"Spine": Vector3(-20, 0, 0), "Chest": Vector3(-10, 0, 0), "LegR": Vector3(30, 0, 0), "ShinR": Vector3(-60, 0, 0),
		"LegL": Vector3(-10, 0, 0), "ShinL": Vector3(-50, 0, 0)}), OUT)
	b.key(length, _merge(st, {"Hips": Vector3(-360, -12, 0), "^Body": Vector3.ONE}), INOUT)
	b.event(0.017, &"dodge_start")
	b.event(length * 0.8, &"footstep")
	lib.add_animation(&"dodge", b.build())


func _hit(lib: AnimationLibrary, st: Dictionary) -> void:
	var d := float(_timing(&"hit").get("length", 0.32))
	var b := AnimBuilder.new(self, &"hit", d)
	b.key(0.0, st)
	b.key(d * 0.18, {"@Hips": Vector3(0, -0.09, 0.05), "Spine": Vector3(14, 0, 4), "Chest": Vector3(12, -10, 0), "Head": Vector3(18, 8, 0),
		"ArmR": AnimBuilder.limb(70, 45, -20), "ArmL": AnimBuilder.limb(-80, 50), "ForearmL": Vector3(70, 0, 0),
		"^Body": Vector3(1.04, 0.95, 1.04)}, SNAP)
	b.key(d, st, INOUT)
	lib.add_animation(&"hit", b.build())

	var dh := float(_timing(&"hit_heavy").get("length", 0.6))
	var bh := AnimBuilder.new(self, &"hit_heavy", dh)
	bh.key(0.0, st)
	bh.key(dh * 0.15, {"@Hips": Vector3(0, -0.2, 0.12), "Hips": Vector3(16, 0, 0), "Spine": Vector3(24, 0, 6), "Chest": Vector3(16, -14, 0), "Head": Vector3(26, 10, 0),
		"ArmR": AnimBuilder.limb(100, 70, -20), "ForearmR": Vector3(30, 0, 0), "ArmL": AnimBuilder.limb(-100, 75), "ForearmL": Vector3(30, 0, 0),
		"LegL": Vector3(40, 0, 10), "ShinL": Vector3(-60, 0, 0), "LegR": Vector3(-10, 0, 0), "ShinR": Vector3(-70, 0, 0),
		"^Body": Vector3(1.06, 0.92, 1.06)}, SNAP)
	bh.key(dh * 0.55, {"@Hips": Vector3(0, -0.16, 0.05), "Hips": Vector3(6, 0, 0), "Spine": Vector3(-20, 0, 0), "Head": Vector3(10, 0, 0)}, INOUT)
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
		"Head": Vector3(-20, 0, 0), "Spine": Vector3(6, 0, 0), "Chest": Vector3(6, 0, 0),
		"ArmR": AnimBuilder.limb(40, 20, -20), "ForearmR": Vector3(50, 0, 0)}
	b.key(0.0, st)
	b.key(apply * 0.7, raise, OUT)
	b.key(apply, _merge(raise, {"@Hips": Vector3(0, -0.02, 0), "^Body": Vector3(0.97, 1.05, 0.97)}), OUT)
	b.key(d, _merge(st, {"^Body": Vector3.ONE}), INOUT)
	b.event(0.017, &"heal_start")
	b.event(apply, &"heal_apply")
	lib.add_animation(&"heal", b.build())


func _cast(lib: AnimationLibrary, st: Dictionary) -> void:
	var tm := _attack_times(&"cast", 0.18, 0.05, 0.3)
	var w: float = tm[0]
	var a: float = tm[1]
	var r: float = tm[2]
	var b := AnimBuilder.new(self, &"cast", w + a + r)
	b.key(0.0, st)
	b.key(w * 0.8, {"Hips": Vector3(0, 20, 0), "Chest": Vector3(0, 30, 0), "ArmL": AnimBuilder.limb(-60, 80), "ForearmL": Vector3(90, 0, 0),
		"ArmR": AnimBuilder.limb(120, 40, -20), "@Hips": Vector3(0, -0.08, 0)}, OUT)
	b.key(w + a, {"Hips": Vector3(0, -10, 0), "Chest": Vector3(-6, -14, 0), "ArmL": AnimBuilder.limb(-5, 92), "ForearmL": Vector3(0, 0, 0), "HandL": Vector3(-60, 0, 0),
		"ArmR": AnimBuilder.limb(140, 50, -20), "@Hips": Vector3(0, -0.1, 0), "^Body": Vector3(0.97, 1.03, 0.97),
		"LegL": Vector3(30, 0, 6), "ShinL": Vector3(-20, 0, 0)}, SNAP)
	b.key(w + a + r, st, INOUT)
	b.event(maxf(w, 0.017), &"cast_fire")
	lib.add_animation(&"cast", b.build())


func _rest(lib: AnimationLibrary, st: Dictionary) -> void:
	var b := AnimBuilder.new(self, &"rest", 0.9)
	b.key(0.0, st)
	b.key(0.6, {"@Hips": Vector3(0, -0.42, 0.05), "Hips": Vector3(0, 0, 0), "Spine": Vector3(-10, 0, 0), "Chest": Vector3(-8, 0, 0), "Head": Vector3(25, 0, 0),
		"LegL": Vector3(85, 0, 4), "ShinL": Vector3(-90, 0, 0), "FootL": Vector3(5, 0, 0),
		"LegR": Vector3(-5, 0, -4), "ShinR": Vector3(-95, 0, 0), "FootR": Vector3(10, 0, 0),
		"ArmR": AnimBuilder.limb(20, 30, -20), "ForearmR": Vector3(60, 0, 0),
		"ArmL": AnimBuilder.limb(-10, 40), "ForearmL": Vector3(80, 0, 0)}, INOUT)
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
	b.key(0.25, {"Spine": Vector3(-20, 0, 0), "ArmR": AnimBuilder.limb(10, 80, -20), "ForearmR": Vector3(10, 0, 0),
		"ArmL": AnimBuilder.limb(-10, 80), "ForearmL": Vector3(10, 0, 0), "@Hips": Vector3(0, -0.1, 0)}, OUT)
	b.key(0.5, {"Spine": Vector3(8, 0, 0), "ArmR": AnimBuilder.limb(10, 40, -20), "ForearmR": Vector3(60, 0, 0),
		"ArmL": AnimBuilder.limb(-10, 40), "ForearmL": Vector3(60, 0, 0), "@Hips": Vector3(0, -0.14, 0.08)}, SNAP)
	b.key(0.8, st, INOUT)
	b.event(0.45, &"interact_point")
	lib.add_animation(&"interact", b.build())
