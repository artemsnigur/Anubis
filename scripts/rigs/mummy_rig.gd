class_name MummyRig
extends EnemyRig
## Mummy Guardian: tall, hunched figure in dirty linen wrappings, gold funerary mask
## with glowing eyes, long reaching arms with trailing bandage strips.


func _build_body() -> void:
	scale = Vector3.ONE * 1.12
	var linen := Mats.get_mat(&"linen")
	var gold := Mats.get_mat(&"gold")
	add_bone("Body", "", Vector3.ZERO)
	add_bone("Hips", "Body", Vector3(0, 0.95, 0))
	part("Hips", box(Vector3(0.38, 0.22, 0.26)), linen)
	part("Hips", cylinder(0.22, 0.27, 0.3, 10), Mats.get_mat(&"wood"), Vector3(0, -0.12, 0))
	add_bone("Spine", "Hips", Vector3(0, 0.1, 0))
	part("Spine", capsule(0.16, 0.36), linen, Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(1.05, 1.0, 0.85))
	add_bone("Chest", "Spine", Vector3(0, 0.26, 0))
	part("Chest", box(Vector3(0.48, 0.34, 0.3)), linen, Vector3(0, 0.1, 0))
	part("Chest", box(Vector3(0.1, 0.1, 0.03)), Mats.get_mat(&"turquoise_stone"), Vector3(0, 0.12, -0.16))
	part("Chest", box(Vector3(0.6, 0.06, 0.32)), linen, Vector3(0, 0.0, 0), Vector3(0, 0, 18))
	add_bone("Neck", "Chest", Vector3(0, 0.3, 0))
	part("Neck", cylinder(0.07, 0.08, 0.14, 8), linen, Vector3(0, 0.04, 0))
	add_bone("Head", "Neck", Vector3(0, 0.1, 0))
	part("Head", sphere(0.15, 0.34, 12), linen, Vector3(0, 0.12, 0))
	part("Head", box(Vector3(0.2, 0.24, 0.05)), gold, Vector3(0, 0.12, -0.13))
	part("Head", box(Vector3(0.06, 0.02, 0.02)), Mats.get_mat(&"eye_glow"), Vector3(0.045, 0.16, -0.16))
	part("Head", box(Vector3(0.06, 0.02, 0.02)), Mats.get_mat(&"eye_glow"), Vector3(-0.045, 0.16, -0.16))
	part("Head", box(Vector3(0.24, 0.05, 0.06)), Mats.get_mat(&"lapis_char"), Vector3(0, 0.24, -0.12))
	for side in ["R", "L"]:
		var sx := 1.0 if side == "R" else -1.0
		build_arm(side, "Chest", Vector3(0.28 * sx, 0.2, 0), 0.36, 0.34, 0.068, linen)
		part("Forearm" + side, box(Vector3(0.05, 0.3, 0.01)), linen, Vector3(0.05 * sx, -0.35, 0.03), Vector3(10, 0, 8 * sx))
		build_leg(side, "Hips", Vector3(0.12 * sx, -0.07, 0), 0.43, 0.42, 0.085, linen)
	add_socket(&"weapon_tip", "HandR", Vector3(0, -0.1, 0))
	add_socket(&"head", "Head", Vector3(0, 0.2, -0.1))
	add_socket(&"grab", "Chest", Vector3(0, 0.3, -0.75))


func _stance() -> Dictionary:
	return {"@Hips": Vector3(0, -0.04, 0), "Spine": Vector3(-18, 0, 0), "Chest": Vector3(-10, 0, 0), "Neck": Vector3(16, 0, 0), "Head": Vector3(10, 0, 0),
		"ArmR": AnimBuilder.limb(15, 42), "ForearmR": Vector3(25, 0, 0), "ArmL": AnimBuilder.limb(-15, 48), "ForearmL": Vector3(30, 0, 0),
		"LegR": Vector3(8, 0, 0), "ShinR": Vector3(-14, 0, 0), "FootR": Vector3(6, 0, 0), "LegL": Vector3(-6, 0, 0), "ShinL": Vector3(-10, 0, 0), "FootL": Vector3(16, 0, 0),
		"^Body": Vector3.ONE}


func _build_clips(lib: AnimationLibrary) -> void:
	var st := _stance()
	sequence_clip(lib, &"idle", 2.6, st, [
		[0.5, {"@Hips": Vector3(0, -0.06, 0), "Spine": Vector3(-20, 0, 4), "Head": Vector3(14, 6, 0), "ArmR": AnimBuilder.limb(18, 46), "ArmL": AnimBuilder.limb(-12, 44)}]], true)
	for spec in [[&"walk", 1.3, 0.6], [&"run", 0.85, 1.0]]:
		var clip: StringName = spec[0]
		var len_s: float = spec[1]
		var k: float = spec[2]
		var b := AnimBuilder.new(self, clip, len_s, true)
		var h := len_s * 0.5
		b.key(0.0, merge(st, {"Spine": Vector3(-20 - 6 * k, 0, 8), "LegR": Vector3(24 * k + 8, 0, 0), "ShinR": Vector3(-10, 0, 0),
			"LegL": Vector3(-14, 0, 0), "ShinL": Vector3(-30, 0, 0), "ArmR": AnimBuilder.limb(10, 50), "ArmL": AnimBuilder.limb(-25, 40)}))
		b.key(h * 0.5, {"@Hips": Vector3(0, 0.0, 0), "LegL": Vector3(10, 0, 0), "ShinL": Vector3(-50, 0, 0)})
		b.key(h, {"@Hips": Vector3(0, -0.07, 0), "Spine": Vector3(-20 - 6 * k, 0, -8), "LegL": Vector3(16 * k + 6, 0, 0), "ShinL": Vector3(-14, 0, 0),
			"LegR": Vector3(-12, 0, 0), "ShinR": Vector3(-26, 0, 0), "ArmR": AnimBuilder.limb(25, 40), "ArmL": AnimBuilder.limb(-10, 52)})
		b.key(h * 1.5, {"@Hips": Vector3(0, -0.02, 0), "LegR": Vector3(8, 0, 0), "ShinR": Vector3(-40, 0, 0)})
		b.event(0.02, &"footstep").event(h + 0.02, &"footstep")
		lib.add_animation(clip, b.build())
	attack_clip(lib, &"slam", st, {
		"windup": {"@Hips": Vector3(0, 0.04, 0.05), "Spine": Vector3(8, 0, 0), "Chest": Vector3(8, 0, 0), "Neck": Vector3(0, 0, 0), "Head": Vector3(-10, 0, 0),
			"ArmR": AnimBuilder.limb(10, 168), "ForearmR": Vector3(60, 0, 0), "ArmL": AnimBuilder.limb(-10, 168), "ForearmL": Vector3(60, 0, 0),
			"^Body": Vector3(0.95, 1.07, 0.95)},
		"hold": {"ArmR": AnimBuilder.limb(10, 178), "ArmL": AnimBuilder.limb(-10, 178), "ForearmR": Vector3(78, 0, 0), "ForearmL": Vector3(78, 0, 0), "Spine": Vector3(12, 0, 0)},
		"strike": {"@Hips": Vector3(0, -0.22, -0.1), "Spine": Vector3(-48, 0, 0), "Chest": Vector3(-20, 0, 0), "Head": Vector3(20, 0, 0),
			"ArmR": AnimBuilder.limb(5, 55), "ForearmR": Vector3(10, 0, 0), "ArmL": AnimBuilder.limb(-5, 55), "ForearmL": Vector3(10, 0, 0),
			"LegR": Vector3(30, 0, 0), "ShinR": Vector3(-50, 0, 0), "LegL": Vector3(-20, 0, 0), "ShinL": Vector3(-30, 0, 0),
			"^Body": Vector3(1.08, 0.9, 1.08)},
		"follow": {"@Hips": Vector3(0, -0.2, -0.1), "Spine": Vector3(-44, 0, 0), "^Body": Vector3.ONE},
	}, 0.95, 0.15, 0.9)
	attack_clip(lib, &"grab", st, {
		"windup": {"Spine": Vector3(-6, 0, 0), "Chest": Vector3(6, 0, 0), "Head": Vector3(0, 0, 0),
			"ArmR": AnimBuilder.limb(105, 82), "ForearmR": Vector3(40, 0, 0), "ArmL": AnimBuilder.limb(-105, 82), "ForearmL": Vector3(40, 0, 0),
			"@Hips": Vector3(0, -0.1, 0.05), "^Body": Vector3(1.04, 0.96, 1.04)},
		"hold": {"ArmR": AnimBuilder.limb(122, 86), "ArmL": AnimBuilder.limb(-122, 86), "Chest": Vector3(10, 0, 0)},
		"strike": {"Spine": Vector3(-28, 0, 0), "Chest": Vector3(-8, 0, 0), "ArmR": AnimBuilder.limb(12, 88), "ForearmR": Vector3(35, 0, 0),
			"ArmL": AnimBuilder.limb(-12, 88), "ForearmL": Vector3(35, 0, 0), "@Hips": Vector3(0, -0.08, -0.15), "^Body": Vector3(0.96, 1.04, 0.96)},
		"follow": {"Spine": Vector3(-24, 0, 0), "^Body": Vector3.ONE},
	}, 0.85, 0.22, 1.0)
	var hold := {"Spine": Vector3(8, 0, 0), "Chest": Vector3(10, 0, 0), "Head": Vector3(-14, 0, 0),
		"ArmR": AnimBuilder.limb(12, 115), "ForearmR": Vector3(50, 0, 0), "ArmL": AnimBuilder.limb(-12, 115), "ForearmL": Vector3(50, 0, 0)}
	sequence_clip(lib, &"grab_hold", 0.5, merge(st, hold), [
		[0.5, {"Chest": Vector3(14, 6, 0), "ArmR": AnimBuilder.limb(14, 120), "ArmL": AnimBuilder.limb(-10, 110), "^Body": Vector3(1.03, 0.97, 1.03)}]], true)
	humanoid_reactions(lib, st, 0.7)
