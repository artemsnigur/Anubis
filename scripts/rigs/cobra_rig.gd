class_name CobraRig
extends EnemyRig
## Cobra Priestess: a priestess torso rising from a coiled serpent tail, cobra hood
## behind the head that flares wide during the venom-spit windup.

const TAIL_SEGMENTS := 8


func _build_body() -> void:
	var scales := Mats.get_mat(&"cobra")
	var belly := Mats.get_mat(&"cobra_belly")
	var skin := Mats.get_mat(&"priestess_skin")
	var gold := Mats.get_mat(&"gold")
	var dress := Mats.get_mat(&"kilt")
	add_bone("Body", "", Vector3.ZERO)
	add_bone("Hips", "Body", Vector3(0, 0.9, 0))
	part("Hips", sphere(0.24, 0.4, 12), scales)
	part("Hips", cylinder(0.2, 0.28, 0.36, 12), dress, Vector3(0, 0.02, 0))
	part("Hips", torus(0.2, 0.25), gold, Vector3(0, 0.18, 0))
	# Tail: drops to the ground, then trails behind in an S curve.
	add_bone("Tail0", "Hips", Vector3(0, -0.2, 0.05))
	part("Tail0", capsule(0.22, 0.75), scales, Vector3(0, -0.32, 0.06), Vector3(-10, 0, 0))
	part("Tail0", capsule(0.16, 0.6), belly, Vector3(0, -0.3, -0.08), Vector3(-10, 0, 0))
	var parent := "Tail0"
	var offs := Vector3(0, -0.62, 0.14)
	for i in range(1, TAIL_SEGMENTS + 1):
		var bone := "Tail%d" % i
		add_bone(bone, parent, offs)
		var r := lerpf(0.21, 0.05, float(i) / float(TAIL_SEGMENTS))
		part(bone, capsule(r, 0.34 + r), scales, Vector3(0, r * 0.9, 0.15), Vector3(90, 0, 0))
		if i % 2 == 0:
			part(bone, torus(r * 0.95, r * 1.12), gold, Vector3(0, r * 0.9, 0.15), Vector3(90, 0, 0))
		parent = bone
		offs = Vector3(0, 0, 0.28)
	add_bone("Spine", "Hips", Vector3(0, 0.15, 0))
	part("Spine", capsule(0.13, 0.32), skin, Vector3(0, 0.1, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
	add_bone("Chest", "Spine", Vector3(0, 0.22, 0))
	part("Chest", box(Vector3(0.38, 0.28, 0.22)), dress, Vector3(0, 0.08, 0))
	part("Chest", cylinder(0.13, 0.27, 0.06, 14), gold, Vector3(0, 0.22, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
	part("Chest", cylinder(0.14, 0.28, 0.04, 14), Mats.get_mat(&"lapis_char"), Vector3(0, 0.18, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
	add_bone("Neck", "Chest", Vector3(0, 0.26, 0))
	part("Neck", cylinder(0.05, 0.06, 0.14, 8), skin, Vector3(0, 0.04, 0))
	add_bone("Hood", "Neck", Vector3(0, 0.12, 0.08))
	part("Hood", sphere(0.3, 0.6, 14), scales, Vector3(0, 0.08, 0.02), Vector3.ZERO, Vector3(1.0, 1.05, 0.18))
	part("Hood", sphere(0.12, 0.24, 10), belly, Vector3(0, 0.08, -0.04), Vector3.ZERO, Vector3(1.6, 2.2, 0.12))
	part("Hood", sphere(0.05, 0.1, 8), gold, Vector3(0.14, 0.18, -0.04), Vector3.ZERO, Vector3(1.0, 1.0, 0.3))
	part("Hood", sphere(0.05, 0.1, 8), gold, Vector3(-0.14, 0.18, -0.04), Vector3.ZERO, Vector3(1.0, 1.0, 0.3))
	add_bone("Head", "Neck", Vector3(0, 0.1, 0))
	part("Head", box(Vector3(0.18, 0.22, 0.19)), skin, Vector3(0, 0.1, 0))
	part("Head", box(Vector3(0.22, 0.2, 0.2)), Mats.get_mat(&"black_glaze"), Vector3(0, 0.16, 0.04))
	part("Head", torus(0.1, 0.13), gold, Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1.0, 0.7, 1.0))
	part("Head", cylinder(0.02, 0.035, 0.12, 6), gold, Vector3(0, 0.27, -0.1), Vector3(-30, 0, 0))
	part("Head", box(Vector3(0.05, 0.02, 0.02)), Mats.get_mat(&"venom"), Vector3(0.045, 0.13, -0.1))
	part("Head", box(Vector3(0.05, 0.02, 0.02)), Mats.get_mat(&"venom"), Vector3(-0.045, 0.13, -0.1))
	for side in ["R", "L"]:
		var sx := 1.0 if side == "R" else -1.0
		build_arm(side, "Chest", Vector3(0.23 * sx, 0.18, 0), 0.28, 0.26, 0.05, skin)
		part("Forearm" + side, torus(0.045, 0.065), gold, Vector3(0, -0.12, 0))
	add_socket(&"weapon_tip", "Head", Vector3(0, 0.08, -0.14))
	add_socket(&"mouth", "Head", Vector3(0, 0.08, -0.14))
	add_socket(&"head", "Head", Vector3(0, 0.2, -0.1))


func _tail_wave(phase: float, amp: float) -> Dictionary:
	var d := {}
	for i in range(1, TAIL_SEGMENTS + 1):
		d["Tail%d" % i] = Vector3(0, sin(phase + float(i) * 1.1) * amp * 1.3, 0)
	return d


func _stance() -> Dictionary:
	return merge({"Spine": Vector3(-6, 0, 0), "Chest": Vector3(-4, 0, 0), "Neck": Vector3(6, 0, 0), "Head": Vector3(4, 0, 0), "Hood": Vector3(-6, 0, 0), "^Hood": Vector3(0.75, 0.8, 1.0),
		"ArmR": AnimBuilder.limb(40, 40), "ForearmR": Vector3(70, 0, 0), "ArmL": AnimBuilder.limb(-40, 40), "ForearmL": Vector3(70, 0, 0),
		"Tail0": Vector3(0, 0, 0), "^Body": Vector3.ONE}, _tail_wave(0.0, 22.0))


func _build_clips(lib: AnimationLibrary) -> void:
	var st := _stance()
	for spec in [[&"idle", 2.4, 14.0, 0.0], [&"walk", 1.0, 26.0, 0.03], [&"run", 0.6, 30.0, 0.05]]:
		var clip: StringName = spec[0]
		var len_s: float = spec[1]
		var amp: float = spec[2]
		var bob: float = spec[3]
		var b := AnimBuilder.new(self, clip, len_s, true)
		b.key(0.0, merge(st, _tail_wave(0.0, amp)))
		for q in range(1, 4):
			var ph := TAU * float(q) / 4.0
			b.key(len_s * float(q) / 4.0, merge(_tail_wave(ph, amp), {"Hips": Vector3(0, sin(ph) * 8.0, sin(ph) * 4.0), "Spine": Vector3(-6 - 6 * bob * 20.0, -sin(ph) * 6.0, 0),
				"@Hips": Vector3(0, cos(ph * 2.0) * bob, 0)}), L)
		lib.add_animation(clip, b.build())
	attack_clip(lib, &"spit", st, {
		"windup": {"Spine": Vector3(14, 0, 0), "Chest": Vector3(10, 0, 0), "Neck": Vector3(-6, 0, 0), "Head": Vector3(-24, 0, 0),
			"Hood": Vector3(-10, 0, 0), "^Hood": Vector3(1.35, 1.3, 1.0), "ArmR": AnimBuilder.limb(100, 100), "ForearmR": Vector3(40, 0, 0),
			"ArmL": AnimBuilder.limb(-100, 100), "ForearmL": Vector3(40, 0, 0), "@Hips": Vector3(0, 0.12, 0.05), "^Body": Vector3(0.96, 1.06, 0.96)},
		"hold": {"Head": Vector3(-30, 0, 0), "^Hood": Vector3(1.45, 1.4, 1.0)},
		"strike": {"Spine": Vector3(-22, 0, 0), "Chest": Vector3(-12, 0, 0), "Neck": Vector3(-16, 0, 0), "Head": Vector3(12, 0, 0),
			"^Hood": Vector3(1.4, 1.35, 1.0), "ArmR": AnimBuilder.limb(130, 60), "ArmL": AnimBuilder.limb(-130, 60), "@Hips": Vector3(0, -0.05, -0.12),
			"^Body": Vector3(1.03, 0.97, 1.03)},
		"follow": {"^Hood": Vector3(1.1, 1.1, 1.0), "^Body": Vector3.ONE},
	}, 0.85, 0.08, 0.6)
	var coil := _tail_wave(1.5, 40.0)
	var lash := _tail_wave(4.5, 45.0)
	attack_clip(lib, &"swipe", st, {
		"windup": merge(coil, {"Spine": Vector3(-14, 30, 0), "Chest": Vector3(0, 20, 0), "^Hood": Vector3(1.2, 1.2, 1.0), "Tail0": Vector3(0, -30, 0),
			"@Hips": Vector3(0, -0.1, 0), "^Body": Vector3(1.05, 0.94, 1.05)}),
		"strike": merge(lash, {"Spine": Vector3(-10, -30, 0), "Chest": Vector3(0, -20, 0), "Tail0": Vector3(0, 40, 0), "^Body": Vector3.ONE}),
	}, 0.5, 0.14, 0.6)
	sequence_clip(lib, &"alert", 0.8, st, [
		[0.3, {"^Hood": Vector3(1.4, 1.35, 1.0), "Head": Vector3(-16, 0, 0), "Spine": Vector3(10, 0, 0), "@Hips": Vector3(0, 0.1, 0)}, OUT],
		[1.0, st, INOUT]])
	sequence_clip(lib, &"hit", clip_length(&"hit", 0.3), st, [
		[0.2, {"Spine": Vector3(18, 0, 6), "Head": Vector3(20, 10, 0), "^Hood": Vector3(0.6, 0.7, 1.0), "^Body": Vector3(1.04, 0.95, 1.04)}, SNAP],
		[1.0, st, INOUT]])
	sequence_clip(lib, &"stagger", clip_length(&"stagger", 1.8), st, [
		[0.1, merge(_tail_wave(2.0, 50.0), {"Spine": Vector3(30, 0, 14), "Chest": Vector3(14, 20, 0), "Head": Vector3(30, -10, 0), "@Hips": Vector3(0, -0.3, 0.1),
			"ArmR": AnimBuilder.limb(110, 80), "ArmL": AnimBuilder.limb(-110, 80), "^Hood": Vector3(0.6, 0.6, 1.0)}), SNAP],
		[0.5, merge(_tail_wave(4.0, 40.0), {"Spine": Vector3(-26, 0, -8), "@Hips": Vector3(0, -0.4, 0)}), INOUT],
		[1.0, st, INOUT]])
	sequence_clip(lib, &"death", 1.5, st, [
		[0.2, {"Spine": Vector3(26, 0, 10), "Head": Vector3(30, 0, 0), "^Hood": Vector3(0.6, 0.6, 1.0)}, SNAP],
		[0.7, merge(_tail_wave(1.0, 30.0), {"@Hips": Vector3(0, -0.65, 0), "Hips": Vector3(-70, 0, 20), "Spine": Vector3(-10, 0, 0), "Head": Vector3(0, 40, 0),
			"ArmR": AnimBuilder.limb(60, 150), "ArmL": AnimBuilder.limb(-60, 130)}), IN],
		[1.0, {"@Hips": Vector3(0, -0.68, 0)}, OUT]])
