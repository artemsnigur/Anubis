class_name AmmitRig
extends EnemyRig
## Ammit, Devourer of Hearts: crocodile head with a hinged jaw full of teeth, lion
## forequarters with a dark mane, hippopotamus hindquarters, armoured crocodile tail.
## Special attacks are single clips whose timeline follows the EnemyAttackData:
## charge (windup -> gallop -> skid), leap (crouch -> airborne -> landing),
## burrow (dive -> hidden -> erupt), roar, summon, tail sweep, double snap.

const TAIL := 6


func _build_body() -> void:
	var croc := Mats.get_mat(&"croc")
	var belly := Mats.get_mat(&"croc_belly")
	var lion := Mats.get_mat(&"lion")
	var mane := Mats.get_mat(&"mane")
	var hippo := Mats.get_mat(&"hippo")
	var teeth := Mats.get_mat(&"teeth")
	var gold := Mats.get_mat(&"gold")
	add_bone("Body", "", Vector3.ZERO)
	add_bone("Pelvis", "Body", Vector3(0, 1.25, 0.8))
	part("Pelvis", sphere(0.95, 1.9, 18), hippo, Vector3(0, 0.05, 0.1), Vector3.ZERO, Vector3(1.15, 0.92, 1.1))
	part("Pelvis", sphere(0.6, 1.2, 12), belly, Vector3(0, -0.45, -0.1), Vector3.ZERO, Vector3(1.3, 0.6, 1.4))
	for i in 4:
		part("Pelvis", prism(Vector3(0.22, 0.25, 0.3)), croc, Vector3(0, 0.98 - float(i) * 0.03, 0.55 - float(i) * 0.38), Vector3(0, 90, 0))
	add_bone("Chest", "Pelvis", Vector3(0, 0.22, -1.45))
	part("Chest", capsule(0.68, 2.1), lion, Vector3(0, 0.0, 0.45), Vector3(90, 0, 0), Vector3(1.0, 1.0, 0.9))
	part("Chest", sphere(0.5, 1.0, 12), belly, Vector3(0, -0.4, 0.1), Vector3.ZERO, Vector3(1.0, 0.7, 1.4))
	for i in 3:
		part("Chest", prism(Vector3(0.2, 0.22, 0.26)), croc, Vector3(0, 0.66, 0.45 - float(i) * 0.35), Vector3(0, 90, 0))
	part("Chest", torus(0.62, 0.72), gold, Vector3(0, 0.05, -0.55), Vector3(90, 0, 0), Vector3(1.0, 1.0, 1.25))
	add_bone("Neck", "Chest", Vector3(0, 0.2, -0.72))
	add_bone("Mane", "Neck", Vector3(0, 0.0, 0.42))
	part("Mane", sphere(0.72, 1.3, 16), mane, Vector3.ZERO, Vector3.ZERO, Vector3(1.1, 1.0, 0.62))
	for i in 10:
		var a := TAU * float(i) / 10.0
		part("Mane", cylinder(0.0, 0.13, 0.5, 6), mane, Vector3(cos(a) * 0.7, sin(a) * 0.65 + 0.05, 0.1), Vector3(0, 0, rad_to_deg(a) - 90.0))
	add_bone("Head", "Neck", Vector3(0, 0.05, -0.45))
	part("Head", box(Vector3(0.66, 0.46, 0.62)), croc, Vector3(0, 0.08, -0.15))
	part("Head", box(Vector3(0.5, 0.26, 1.15)), croc, Vector3(0, 0.0, -0.95), Vector3(-3, 0, 0))
	part("Head", box(Vector3(0.56, 0.08, 0.3)), croc, Vector3(0, 0.28, -0.08))
	part("Head", box(Vector3(0.18, 0.08, 0.12)), croc, Vector3(0.12, 0.13, -1.45))
	part("Head", box(Vector3(0.18, 0.08, 0.12)), croc, Vector3(-0.12, 0.13, -1.45))
	part("Head", box(Vector3(0.12, 0.06, 0.08)), Mats.get_mat(&"eye_red"), Vector3(0.22, 0.3, -0.32))
	part("Head", box(Vector3(0.12, 0.06, 0.08)), Mats.get_mat(&"eye_red"), Vector3(-0.22, 0.3, -0.32))
	for sx: float in [1.0, -1.0]:
		for i in 6:
			part("Head", cylinder(0.0, 0.045, 0.16, 4), teeth, Vector3(0.21 * sx, -0.17, -0.45 - float(i) * 0.18), Vector3(180, 0, 0))
	add_bone("Jaw", "Head", Vector3(0, -0.14, -0.1))
	part("Jaw", box(Vector3(0.46, 0.16, 1.15)), belly, Vector3(0, -0.06, -0.85))
	part("Jaw", box(Vector3(0.5, 0.06, 1.15)), croc, Vector3(0, -0.15, -0.85))
	for sx: float in [1.0, -1.0]:
		for i in 6:
			part("Jaw", cylinder(0.0, 0.04, 0.14, 4), teeth, Vector3(0.19 * sx, 0.07, -0.45 - float(i) * 0.18))
	for side in ["R", "L"]:
		var sx := 1.0 if side == "R" else -1.0
		add_bone("Front" + side, "Chest", Vector3(0.5 * sx, -0.25, -0.35))
		part("Front" + side, capsule(0.25, 0.85), lion, Vector3(0, -0.35, 0))
		add_bone("FrontShin" + side, "Front" + side, Vector3(0, -0.72, 0))
		part("FrontShin" + side, capsule(0.19, 0.7), lion, Vector3(0, -0.28, 0))
		add_bone("Paw" + side, "FrontShin" + side, Vector3(0, -0.58, 0))
		part("Paw" + side, box(Vector3(0.36, 0.18, 0.46)), lion, Vector3(0, -0.04, -0.12))
		for c in 3:
			part("Paw" + side, cylinder(0.0, 0.035, 0.14, 4), Mats.get_mat(&"bone"), Vector3((float(c) - 1.0) * 0.1, -0.06, -0.38), Vector3(-90, 0, 0))
		add_bone("Hind" + side, "Pelvis", Vector3(0.62 * sx, -0.3, 0.25))
		part("Hind" + side, cylinder(0.34, 0.4, 0.75, 12), hippo, Vector3(0, -0.25, 0))
		add_bone("HindShin" + side, "Hind" + side, Vector3(0, -0.55, 0))
		part("HindShin" + side, cylinder(0.3, 0.33, 0.5, 12), hippo, Vector3(0, -0.2, 0))
		add_bone("HindFoot" + side, "HindShin" + side, Vector3(0, -0.4, 0))
		part("HindFoot" + side, cylinder(0.36, 0.36, 0.14, 12), hippo, Vector3(0, -0.02, -0.05))
	var parent := "Pelvis"
	var offs := Vector3(0, -0.15, 1.0)
	for i in range(1, TAIL + 1):
		var bone := "Tail%d" % i
		add_bone(bone, parent, offs)
		var r := lerpf(0.45, 0.1, float(i - 1) / float(TAIL - 1))
		part(bone, capsule(r, 0.75 + r), croc, Vector3(0, 0, 0.33), Vector3(90, 0, 0), Vector3(1.0, 1.0, 0.85))
		part(bone, prism(Vector3(r * 0.6, r * 0.6, 0.3)), croc, Vector3(0, r * 0.85, 0.3), Vector3(0, 90, 0))
		parent = bone
		offs = Vector3(0, 0, 0.62)
	(bones["Head"] as Node3D).scale = Vector3.ONE * 1.3
	add_socket(&"weapon_tip", "Head", Vector3(0, 0.0, -1.5))
	add_socket(&"mouth", "Head", Vector3(0, -0.1, -1.2))
	add_socket(&"head", "Head", Vector3(0, 0.45, -0.4))
	add_socket(&"tail_tip", "Tail%d" % TAIL, Vector3(0, 0, 0.6))


func _tail(curl: float, lift: float, phase: float = 0.0) -> Dictionary:
	var d := {}
	for i in range(1, TAIL + 1):
		d["Tail%d" % i] = Vector3(lift * (1.0 if i == 1 else 0.3) + 6.0, sin(phase + float(i) * 0.8) * curl, 0)
	return d


func _legs(fr: float, fl: float, hr: float, hl: float, bend: float = 0.0) -> Dictionary:
	return {"FrontR": Vector3(fr, 0, 0), "FrontL": Vector3(fl, 0, 0), "FrontShinR": Vector3(-bend - maxf(-fr, 0.0) * 0.6, 0, 0),
		"FrontShinL": Vector3(-bend - maxf(-fl, 0.0) * 0.6, 0, 0), "PawR": Vector3(-fr * 0.5, 0, 0), "PawL": Vector3(-fl * 0.5, 0, 0),
		"HindR": Vector3(hr, 0, 0), "HindL": Vector3(hl, 0, 0), "HindShinR": Vector3(-absf(hr) * 0.4, 0, 0), "HindShinL": Vector3(-absf(hl) * 0.4, 0, 0),
		"HindFootR": Vector3(-hr * 0.5, 0, 0), "HindFootL": Vector3(-hl * 0.5, 0, 0)}


func _stance() -> Dictionary:
	return merge(merge({"@Body": Vector3.ZERO, "Pelvis": Vector3.ZERO, "Chest": Vector3(-4, 0, 0), "Neck": Vector3(-6, 0, 0), "Head": Vector3(4, 0, 0),
		"Jaw": Vector3(-4, 0, 0), "^Mane": Vector3.ONE, "^Body": Vector3.ONE}, _legs(0, 0, 0, 0)), _tail(10.0, 0.0))


func _build_clips(lib: AnimationLibrary) -> void:
	var st := _stance()
	sequence_clip(lib, &"idle", 2.4, st, [
		[0.5, merge({"Chest": Vector3(-2, 0, 0), "Neck": Vector3(-2, 4, 0), "^Mane": Vector3(1.04, 1.04, 1.04), "Jaw": Vector3(-8, 0, 0)}, _tail(14.0, 2.0, 1.5))]], true)
	for spec in [[&"walk", 1.3, 0.6], [&"run", 0.75, 1.0]]:
		var clip: StringName = spec[0]
		var len_s: float = spec[1]
		var k: float = spec[2]
		var a := 22.0 + 14.0 * k
		var b := AnimBuilder.new(self, clip, len_s, true)
		b.key(0.0, merge(merge(st, _legs(a, -a, -a, a, 10.0)), merge({"@Body": Vector3(0, -0.04, 0), "Chest": Vector3(-4 - 4 * k, 6 * k, 0), "Neck": Vector3(-10 * k, -4, 0)}, _tail(16.0, 0.0, 0.0))), INOUT)
		b.key(len_s * 0.25, {"@Body": Vector3(0, 0.06 * k, 0), "FrontShinR": Vector3(-40, 0, 0), "HindShinL": Vector3(-30, 0, 0)}, INOUT)
		b.key(len_s * 0.5, merge(merge(_legs(-a, a, a, -a, 10.0), {"@Body": Vector3(0, -0.04, 0), "Chest": Vector3(-4 - 4 * k, -6 * k, 0), "Neck": Vector3(-10 * k, 4, 0)}), _tail(16.0, 0.0, PI)), INOUT)
		b.key(len_s * 0.75, {"@Body": Vector3(0, 0.06 * k, 0), "FrontShinL": Vector3(-40, 0, 0), "HindShinR": Vector3(-30, 0, 0)}, INOUT)
		b.event(0.02, &"footstep").event(len_s * 0.5 + 0.02, &"footstep")
		lib.add_animation(clip, b.build())
	_snap(lib, st, &"snap_1", 0.55, 0.12, 0.9)
	_snap(lib, st, &"snap_2", 0.35, 0.12, 0.9)
	_tail_sweep(lib, st)
	_charge(lib, st)
	_leap(lib, st)
	_roar(lib, st, &"roar", 0.4, 1.4, 0.4)
	_roar(lib, st, &"alert", 0.3, 1.0, 0.4)
	_summon(lib, st)
	_burrow(lib, st)
	sequence_clip(lib, &"hit", clip_length(&"hit", 0.25), st, [
		[0.3, {"Neck": Vector3(14, 8, 0), "Head": Vector3(10, 0, 0), "Jaw": Vector3(-20, 0, 0), "^Body": Vector3(1.03, 0.97, 1.03)}, SNAP],
		[1.0, st, INOUT]])
	var down := merge(merge({"@Body": Vector3(0, -0.55, 0), "Pelvis": Vector3(0, 0, 24), "Chest": Vector3(-8, 0, 10), "Neck": Vector3(-24, 14, 0),
		"Head": Vector3(-10, 0, 10), "Jaw": Vector3(-30, 0, 0)}, _legs(30, 50, -20, 40, 30.0)), _tail(25.0, -10.0, 2.0))
	sequence_clip(lib, &"stagger", clip_length(&"stagger", 3.0), st, [
		[0.08, merge(down, {"@Body": Vector3(0, -0.2, 0.2), "^Body": Vector3(1.08, 0.9, 1.08)}), SNAP],
		[0.2, down, IN],
		[0.55, merge(down, {"Neck": Vector3(-20, 20, 0), "Jaw": Vector3(-10, 0, 0)}), INOUT],
		[0.82, merge(down, {"@Body": Vector3(0, -0.4, 0), "Pelvis": Vector3(0, 0, 14), "Neck": Vector3(0, 0, 0)}), INOUT],
		[1.0, st, INOUT]])
	sequence_clip(lib, &"crash", 0.6, st, [
		[0.2, {"Neck": Vector3(30, 0, 0), "Head": Vector3(20, 0, 0), "Jaw": Vector3(-40, 0, 0), "@Body": Vector3(0, -0.1, 0.3), "^Body": Vector3(1.1, 0.88, 1.06)}, SNAP],
		[1.0, merge(down, {"@Body": Vector3(0, -0.3, 0)}), INOUT]])
	sequence_clip(lib, &"death", 2.2, st, [
		[0.15, {"Neck": Vector3(35, 0, 0), "Head": Vector3(20, 0, 0), "Jaw": Vector3(-60, 0, 0), "Pelvis": Vector3(10, 0, 0)}, SNAP],
		[0.5, merge(down, {"@Body": Vector3(0, -0.5, 0), "Pelvis": Vector3(0, 0, 40)}), IN],
		[0.8, merge(merge(down, _legs(40, 70, -40, 60, 40.0)), {"@Body": Vector3(0, -0.7, 0), "Pelvis": Vector3(0, 0, 78), "Neck": Vector3(-20, 30, 0), "Jaw": Vector3(-50, 0, 0)}), IN],
		[1.0, {"@Body": Vector3(0, -0.72, 0)}, OUT]])


func _times(clip: StringName, w: float, a: float, r: float) -> Array:
	var tm: Dictionary = clip_table.get(clip, {})
	return [float(tm.get("windup", w)), float(tm.get("active", a)), float(tm.get("recovery", r)), float(tm.get("lead", w * 0.4))]


func _events(b: AnimBuilder, w: float, a: float, lead: float) -> void:
	b.event(maxf(w - lead, 0.017), &"telegraph")
	b.event(maxf(w * 0.9, 0.017), &"swing")
	b.event(maxf(w, 0.02), &"hitbox_on")
	b.event(w + a, &"hitbox_off")


func _snap(lib: AnimationLibrary, st: Dictionary, clip: StringName, dw: float, da: float, dr: float) -> void:
	var t := _times(clip, dw, da, dr)
	var w: float = t[0]
	var a: float = t[1]
	var r: float = t[2]
	var b := AnimBuilder.new(self, clip, w + a + r)
	b.key(0.0, st)
	var open := merge({"Chest": Vector3(6, 0, 0), "Neck": Vector3(22, 0, 0), "Head": Vector3(16, 0, 0), "Jaw": Vector3(-58, 0, 0), "@Body": Vector3(0, 0.05, 0.35),
		"^Mane": Vector3(1.12, 1.12, 1.12), "^Body": Vector3(0.97, 1.04, 0.97)}, _legs(-10, 8, -6, 6))
	b.key(w * 0.75, open, OUT)
	b.key(w, merge(open, {"Neck": Vector3(26, 0, 0), "Jaw": Vector3(-66, 0, 0)}), INOUT)
	b.key(w + a, merge({"Chest": Vector3(-10, 0, 0), "Neck": Vector3(-18, 0, 0), "Head": Vector3(-8, 0, 0), "Jaw": Vector3(2, 0, 0), "@Body": Vector3(0, -0.12, -0.45),
		"^Mane": Vector3.ONE, "^Body": Vector3(1.05, 0.94, 1.05)}, _legs(28, -10, 10, -10)), SNAP)
	b.key(w + a + r * 0.35, {"Neck": Vector3(-14, 0, 0), "^Body": Vector3.ONE}, OUT)
	b.key(w + a + r, st, INOUT)
	_events(b, w, a, float(t[3]))
	lib.add_animation(clip, b.build())


func _tail_sweep(lib: AnimationLibrary, st: Dictionary) -> void:
	var t := _times(&"tail", 0.75, 0.3, 0.75)
	var w: float = t[0]
	var a: float = t[1]
	var r: float = t[2]
	var b := AnimBuilder.new(self, &"tail", w + a + r)
	b.key(0.0, st)
	var coil := merge(merge({"Pelvis": Vector3(0, 28, 0), "Chest": Vector3(0, 18, 0), "Neck": Vector3(0, -30, 0), "@Body": Vector3(0, -0.15, 0), "^Body": Vector3(1.04, 0.95, 1.04)},
		_legs(10, -10, -10, 10, 20.0)), _tail(30.0, -25.0, 1.0))
	b.key(w * 0.8, coil, OUT)
	b.key(w, merge(coil, _tail(35.0, -30.0, 1.4)), INOUT)
	b.key(w + a, merge(merge({"Pelvis": Vector3(0, -26, 0), "Chest": Vector3(0, -16, 0), "Neck": Vector3(0, 24, 0), "@Body": Vector3(0, -0.05, 0), "^Body": Vector3.ONE},
		_legs(-10, 10, 10, -10, 10.0)), _tail(40.0, -10.0, 4.5)), SNAP)
	b.key(w + a + r, st, INOUT)
	_events(b, w, a, float(t[3]))
	lib.add_animation(&"tail", b.build())


func _charge(lib: AnimationLibrary, st: Dictionary) -> void:
	var t := _times(&"charge", 0.95, 2.0, 0.9)
	var w: float = t[0]
	var a: float = t[1]
	var r: float = t[2]
	var b := AnimBuilder.new(self, &"charge", w + a + r)
	b.key(0.0, st)
	var scrape := merge({"Pelvis": Vector3(-6, 0, 0), "Chest": Vector3(-10, 0, 0), "Neck": Vector3(-22, 0, 0), "Head": Vector3(-6, 0, 0), "@Body": Vector3(0, 0.08, 0.25),
		"Jaw": Vector3(-20, 0, 0)}, _tail(8.0, -15.0))
	b.key(w * 0.3, merge(scrape, _legs(35, 0, -20, -20, 0.0)), OUT)
	b.key(w * 0.55, merge(scrape, _legs(-30, 0, -20, -20, 10.0)), SNAP)
	b.key(w * 0.8, merge(scrape, _legs(35, 0, -25, -25, 0.0)), OUT)
	b.key(w, merge(scrape, merge(_legs(-25, 0, -30, -30, 10.0), {"^Body": Vector3(1.06, 0.92, 1.06)})), SNAP)
	# Gallop: front pair / hind pair alternate, body rocks.
	var cycle := 0.42
	var tt := w
	var flip := false
	while tt + cycle * 0.5 < w + a:
		tt += cycle * 0.5
		var s := 1.0 if flip else -1.0
		b.key(tt, merge(merge(_legs(40 * s, 34 * s, -40 * s, -34 * s, 15.0), {"Pelvis": Vector3(6 * s, 0, 0), "@Body": Vector3(0, 0.12 if flip else -0.02, 0),
			"Neck": Vector3(-24, 0, 0), "Jaw": Vector3(-28, 0, 0), "^Body": Vector3.ONE}), _tail(10.0, -8.0, tt * 6.0)), INOUT)
		flip = not flip
	b.key(w + a + r * 0.3, merge(merge(_legs(45, 45, 25, 25, 0.0), {"Pelvis": Vector3(-12, 0, 0), "Neck": Vector3(10, 0, 0), "@Body": Vector3(0, -0.15, 0)}), _tail(30.0, -10.0, 2.0)), OUT)
	b.key(w + a + r, st, INOUT)
	_events(b, w, a, float(t[3]))
	b.event(w + 0.2, &"footstep").event(w + 0.6, &"footstep").event(w + 1.0, &"footstep").event(w + 1.4, &"footstep")
	lib.add_animation(&"charge", b.build())


func _leap(lib: AnimationLibrary, st: Dictionary) -> void:
	var t := _times(&"leap", 0.8, 0.7, 1.1)
	var w: float = t[0]
	var a: float = t[1]
	var r: float = t[2]
	var b := AnimBuilder.new(self, &"leap", w + a + r)
	b.key(0.0, st)
	var crouch := merge(merge({"@Body": Vector3(0, -0.42, 0.1), "Pelvis": Vector3(4, 0, 0), "Neck": Vector3(-6, 0, 0), "Jaw": Vector3(-24, 0, 0), "^Body": Vector3(1.1, 0.85, 1.1)},
		_legs(-10, -10, -20, -20, 40.0)), _tail(12.0, -10.0))
	b.key(w * 0.85, crouch, OUT)
	b.key(w, merge(crouch, {"@Body": Vector3(0, -0.5, 0.1)}), INOUT)
	b.key(w + a * 0.25, merge(merge({"@Body": Vector3(0, 0.1, 0), "Pelvis": Vector3(16, 0, 0), "Neck": Vector3(10, 0, 0), "Jaw": Vector3(-45, 0, 0), "^Body": Vector3(0.92, 1.12, 0.92)},
		_legs(55, 55, -55, -55, 0.0)), _tail(6.0, 10.0)), SNAP)
	b.key(w + a * 0.8, merge(_legs(30, 30, -10, -10, 10.0), {"Pelvis": Vector3(-10, 0, 0), "Neck": Vector3(-10, 0, 0), "^Body": Vector3.ONE}), INOUT)
	b.key(w + a, merge(merge({"@Body": Vector3(0, -0.45, 0), "Pelvis": Vector3(-4, 0, 0), "Neck": Vector3(-20, 0, 0), "Jaw": Vector3(-10, 0, 0), "^Body": Vector3(1.14, 0.82, 1.14)},
		_legs(20, 20, -20, -20, 40.0)), _tail(20.0, 0.0, 2.0)), SNAP)
	b.key(w + a + r * 0.4, {"@Body": Vector3(0, -0.2, 0), "^Body": Vector3.ONE}, OUT)
	b.key(w + a + r, st, INOUT)
	_events(b, w, a, float(t[3]))
	lib.add_animation(&"leap", b.build())


func _roar(lib: AnimationLibrary, st: Dictionary, clip: StringName, dw: float, da: float, dr: float) -> void:
	var t := _times(clip, dw, da, dr)
	var w: float = t[0]
	var a: float = t[1]
	var r: float = t[2]
	var b := AnimBuilder.new(self, clip, w + a + r)
	b.key(0.0, st)
	var rear := merge(merge({"Pelvis": Vector3(10, 0, 0), "Chest": Vector3(8, 0, 0), "Neck": Vector3(36, 0, 0), "Head": Vector3(20, 0, 0), "Jaw": Vector3(-62, 0, 0),
		"^Mane": Vector3(1.3, 1.3, 1.3), "^Body": Vector3(0.96, 1.06, 0.96)}, _legs(20, 20, -10, -10, 0.0)), _tail(25.0, -20.0, 1.0))
	b.key(w, rear, OUT)
	for i in 4:
		b.key(w + a * (float(i) + 0.5) / 4.0, {"Neck": Vector3(34 + (i % 2) * 6, (i % 2) * 8 - 4, 0), "^Mane": Vector3(1.34, 1.34, 1.34) if i % 2 == 0 else Vector3(1.24, 1.24, 1.24)}, INOUT)
	b.key(w + a, merge(rear, {"Neck": Vector3(30, 0, 0)}), INOUT)
	b.key(w + a + r, st, INOUT)
	b.event(maxf(w * 0.8, 0.017), &"telegraph")
	b.event(maxf(w, 0.02), &"hitbox_on")
	b.event(w + a, &"hitbox_off")
	lib.add_animation(clip, b.build())


func _summon(lib: AnimationLibrary, st: Dictionary) -> void:
	var t := _times(&"summon", 1.0, 0.3, 0.8)
	var w: float = t[0]
	var a: float = t[1]
	var r: float = t[2]
	var b := AnimBuilder.new(self, &"summon", w + a + r)
	b.key(0.0, st)
	var up := merge(merge({"Pelvis": Vector3(34, 0, 0), "Chest": Vector3(6, 0, 0), "Neck": Vector3(30, 0, 0), "Head": Vector3(10, 0, 0), "Jaw": Vector3(-55, 0, 0),
		"@Body": Vector3(0, 0.2, 0.3), "^Mane": Vector3(1.25, 1.25, 1.25)}, _legs(70, 55, -30, -30, 50.0)), _tail(10.0, 20.0))
	b.key(w * 0.7, up, OUT)
	b.key(w, merge(up, {"Pelvis": Vector3(38, 0, 0), "FrontR": Vector3(80, 0, 0)}), INOUT)
	b.key(w + a, merge(merge({"Pelvis": Vector3(-6, 0, 0), "@Body": Vector3(0, -0.2, -0.1), "Neck": Vector3(-20, 0, 0), "^Body": Vector3(1.12, 0.86, 1.12), "^Mane": Vector3.ONE},
		_legs(10, 10, -10, -10, 30.0)), _tail(25.0, 0.0, 3.0)), SNAP)
	b.key(w + a + r, st, INOUT)
	b.event(maxf(w * 0.5, 0.017), &"telegraph")
	b.event(maxf(w, 0.02), &"hitbox_on")
	b.event(w + a, &"hitbox_off")
	lib.add_animation(&"summon", b.build())


func _burrow(lib: AnimationLibrary, st: Dictionary) -> void:
	var t := _times(&"burrow", 0.8, 2.2, 1.3)
	var w: float = t[0]
	var a: float = t[1]
	var r: float = t[2]
	var b := AnimBuilder.new(self, &"burrow", w + a + r)
	b.key(0.0, st)
	var dive := merge(merge({"Pelvis": Vector3(-28, 0, 0), "Neck": Vector3(-30, 0, 0), "Head": Vector3(-14, 0, 0), "Jaw": Vector3(-10, 0, 0)}, _legs(50, 50, -30, -30, 30.0)), _tail(8.0, 20.0))
	b.key(w * 0.4, merge(dive, {"@Body": Vector3(0, 0.25, -0.3), "^Body": Vector3(0.95, 1.05, 0.95)}), OUT)
	b.key(w, merge(dive, {"@Body": Vector3(0, -2.9, -0.6), "^Body": Vector3(0.9, 1.1, 0.9)}), IN)
	b.key(w + a - 0.12, merge(dive, {"@Body": Vector3(0, -2.9, 0.0), "Pelvis": Vector3(40, 0, 0), "Neck": Vector3(40, 0, 0), "Jaw": Vector3(-60, 0, 0)}), L)
	b.key(w + a + 0.12, merge(merge({"@Body": Vector3(0, 0.6, 0.0), "Pelvis": Vector3(38, 0, 0), "Neck": Vector3(34, 0, 0), "Head": Vector3(10, 0, 0), "Jaw": Vector3(-64, 0, 0),
		"^Body": Vector3(0.9, 1.15, 0.9), "^Mane": Vector3(1.3, 1.3, 1.3)}, _legs(60, 50, -20, -20, 20.0)), _tail(20.0, 10.0)), SNAP)
	b.key(w + a + r * 0.35, merge(merge({"@Body": Vector3(0, -0.3, 0), "Pelvis": Vector3(-4, 0, 0), "Neck": Vector3(-10, 0, 0), "Jaw": Vector3(-20, 0, 0),
		"^Body": Vector3(1.12, 0.86, 1.12), "^Mane": Vector3.ONE}, _legs(15, 15, -15, -15, 35.0)), _tail(20.0, 0.0, 2.0)), IN)
	b.key(w + a + r, st, INOUT)
	_events(b, w, a, float(t[3]))
	lib.add_animation(&"burrow", b.build())
