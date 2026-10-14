class_name JackalRig
extends EnemyRig
## Jackal Warrior: lean black-basalt warrior with a jackal head, tall ears, gold collar,
## white kilt and a bronze khopesh. Agile poses with deep crouches.


func _build_body() -> void:
	scale = Vector3.ONE * 1.05
	var skin := Mats.get_mat(&"jackal")
	var gold := Mats.get_mat(&"gold")
	var kilt := Mats.get_mat(&"kilt")
	add_bone("Body", "", Vector3.ZERO)
	add_bone("Hips", "Body", Vector3(0, 0.98, 0))
	part("Hips", box(Vector3(0.32, 0.18, 0.2)), skin)
	part("Hips", cylinder(0.19, 0.3, 0.38, 10), kilt, Vector3(0, -0.14, 0))
	part("Hips", box(Vector3(0.36, 0.06, 0.24)), gold, Vector3(0, 0.05, 0))
	part("Hips", box(Vector3(0.12, 0.34, 0.03)), Mats.get_mat(&"lapis_char"), Vector3(0, -0.15, -0.16))
	add_bone("Spine", "Hips", Vector3(0, 0.1, 0))
	part("Spine", capsule(0.13, 0.34), skin, Vector3(0, 0.12, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
	add_bone("Chest", "Spine", Vector3(0, 0.25, 0))
	part("Chest", box(Vector3(0.46, 0.3, 0.24)), skin, Vector3(0, 0.1, 0))
	part("Chest", cylinder(0.14, 0.3, 0.07, 14), gold, Vector3(0, 0.25, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
	part("Chest", cylinder(0.15, 0.31, 0.04, 14), Mats.get_mat(&"lapis_char"), Vector3(0, 0.2, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.8))
	add_bone("Neck", "Chest", Vector3(0, 0.29, 0))
	part("Neck", cylinder(0.06, 0.07, 0.14, 8), skin, Vector3(0, 0.04, 0))
	add_bone("Head", "Neck", Vector3(0, 0.1, 0))
	part("Head", box(Vector3(0.2, 0.2, 0.22)), skin, Vector3(0, 0.1, 0))
	part("Head", box(Vector3(0.12, 0.11, 0.26)), skin, Vector3(0, 0.05, -0.2), Vector3(8, 0, 0))
	part("Head", box(Vector3(0.07, 0.06, 0.06)), Mats.get_mat(&"black_glaze"), Vector3(0, 0.05, -0.34))
	for sx: float in [1.0, -1.0]:
		part("Head", cylinder(0.0, 0.06, 0.26, 4), skin, Vector3(0.07 * sx, 0.3, 0.03), Vector3(-8, 45, 8 * sx))
		part("Head", box(Vector3(0.05, 0.02, 0.02)), Mats.get_mat(&"eye_gold"), Vector3(0.06 * sx, 0.13, -0.11))
	part("Head", box(Vector3(0.22, 0.05, 0.2)), gold, Vector3(0, 0.02, 0.02))
	for side in ["R", "L"]:
		var sx := 1.0 if side == "R" else -1.0
		build_arm(side, "Chest", Vector3(0.27 * sx, 0.2, 0), 0.32, 0.3, 0.06, skin)
		part("Forearm" + side, torus(0.05, 0.075), gold, Vector3(0, -0.18, 0))
		build_leg(side, "Hips", Vector3(0.11 * sx, -0.07, 0), 0.44, 0.44, 0.075, skin)
		part("Shin" + side, torus(0.055, 0.085), gold, Vector3(0, -0.34, 0))
	var socket := add_socket(&"weapon_r", "HandR", Vector3(0, -0.06, -0.01), Vector3(82, 0, 0))
	var grip := MeshInstance3D.new()
	grip.mesh = cylinder(0.022, 0.022, 0.18, 8)
	grip.material_override = Mats.get_mat(&"wood")
	socket.add_child(grip)
	var blade := MeshInstance3D.new()
	blade.mesh = cached_mesh("khopesh", KhopeshMesh.build)
	blade.material_override = Mats.get_mat(&"bronze")
	socket.add_child(blade)
	var tip := Node3D.new()
	tip.position = Vector3(0, -0.5, -0.25)
	socket.add_child(tip)
	sockets[&"weapon_tip"] = tip
	add_socket(&"head", "Head", Vector3(0, 0.2, -0.1))


func _stance() -> Dictionary:
	return {"@Hips": Vector3(0, -0.09, 0), "Hips": Vector3(0, -16, 0), "Spine": Vector3(-12, 10, 0), "Chest": Vector3(-6, 8, 0), "Neck": Vector3(6, 0, 0), "Head": Vector3(8, -6, 0),
		"ArmR": AnimBuilder.limb(40, 45, -20), "ForearmR": Vector3(70, 0, 0), "ArmL": AnimBuilder.limb(-40, 38), "ForearmL": Vector3(60, 0, 0),
		"LegR": Vector3(-20, 0, -8), "ShinR": Vector3(-34, 0, 0), "FootR": Vector3(30, 0, 0), "LegL": Vector3(26, 0, 8), "ShinL": Vector3(-26, 0, 0), "FootL": Vector3(0, 0, 0),
		"^Body": Vector3.ONE}


func _build_clips(lib: AnimationLibrary) -> void:
	var st := _stance()
	sequence_clip(lib, &"idle", 1.6, st, [
		[0.5, {"@Hips": Vector3(0, -0.12, 0), "Chest": Vector3(-3, 12, 0), "ArmR": AnimBuilder.limb(44, 48, -20), "ShinR": Vector3(-40, 0, 0), "ShinL": Vector3(-32, 0, 0)}]], true)
	for spec in [[&"walk", 0.9, 0.5], [&"run", 0.52, 1.0]]:
		var clip: StringName = spec[0]
		var len_s: float = spec[1]
		var k: float = spec[2]
		var b := AnimBuilder.new(self, clip, len_s, true)
		var h := len_s * 0.5
		var stride := 26.0 + 18.0 * k
		var base := {"Spine": Vector3(-10 - 12 * k, 0, 0), "Head": Vector3(10 * k, 0, 0), "ForearmR": Vector3(70, 0, 0), "ForearmL": Vector3(60, 0, 0), "^Body": Vector3.ONE, "Hips": Vector3.ZERO}
		b.key(0.0, merge(base, {"@Hips": Vector3(0, -0.06 - 0.04 * k, 0), "Chest": Vector3(0, -10 * k, 0), "LegR": Vector3(stride, 0, 0), "ShinR": Vector3(-8, 0, 0), "FootR": Vector3(-8, 0, 0),
			"LegL": Vector3(-stride * 0.8, 0, 0), "ShinL": Vector3(-40 - 30 * k, 0, 0), "FootL": Vector3(30, 0, 0),
			"ArmR": AnimBuilder.limb(30, 30 + 10 * k, -20), "ArmL": AnimBuilder.limb(-20, 20 + 30 * k)}))
		b.key(h * 0.5, {"@Hips": Vector3(0, -0.02 + 0.03 * k, 0), "LegR": Vector3(0, 0, 0), "ShinR": Vector3(-12, 0, 0),
			"LegL": Vector3(stride * 0.5, 0, 0), "ShinL": Vector3(-80 - 30 * k, 0, 0), "FootL": Vector3(10, 0, 0)})
		b.key(h, {"@Hips": Vector3(0, -0.06 - 0.04 * k, 0), "Chest": Vector3(0, 10 * k, 0), "LegL": Vector3(stride, 0, 0), "ShinL": Vector3(-8, 0, 0), "FootL": Vector3(-8, 0, 0),
			"LegR": Vector3(-stride * 0.8, 0, 0), "ShinR": Vector3(-40 - 30 * k, 0, 0), "FootR": Vector3(30, 0, 0),
			"ArmR": AnimBuilder.limb(45, 40 + 10 * k, -20), "ArmL": AnimBuilder.limb(-160, 15 + 25 * k)})
		b.key(h * 1.5, {"@Hips": Vector3(0, -0.02 + 0.03 * k, 0), "LegL": Vector3(0, 0, 0), "ShinL": Vector3(-12, 0, 0),
			"LegR": Vector3(stride * 0.5, 0, 0), "ShinR": Vector3(-80 - 30 * k, 0, 0), "FootR": Vector3(10, 0, 0)})
		b.event(0.02, &"footstep").event(h + 0.02, &"footstep")
		lib.add_animation(clip, b.build())
	attack_clip(lib, &"combo_1", st, {
		"windup": {"@Hips": Vector3(0, -0.14, 0), "Hips": Vector3(0, -30, 0), "Spine": Vector3(-8, -20, 0), "Chest": Vector3(-2, -34, 4),
			"ArmR": AnimBuilder.limb(120, 85, -40), "ForearmR": Vector3(45, 0, 0), "ArmL": AnimBuilder.limb(-50, 55), "^Body": Vector3(1.04, 0.95, 1.04)},
		"hold": {"Chest": Vector3(-2, -42, 6), "ArmR": AnimBuilder.limb(132, 88, -40)},
		"strike": {"@Hips": Vector3(0, -0.15, 0), "Hips": Vector3(0, 20, 0), "Spine": Vector3(-16, 18, 0), "Chest": Vector3(-6, 38, -4),
			"ArmR": AnimBuilder.limb(-55, 86, 10), "ForearmR": Vector3(8, 0, 0), "ArmL": AnimBuilder.limb(-120, 40),
			"LegL": Vector3(38, 0, 8), "ShinL": Vector3(-30, 0, 0), "^Body": Vector3(0.97, 1.04, 0.97)},
		"follow": {"Chest": Vector3(-6, 46, -4), "ArmR": AnimBuilder.limb(-72, 78, 10), "^Body": Vector3.ONE},
	}, 0.45, 0.1, 0.6)
	var from2 := {"@Hips": Vector3(0, -0.15, 0), "Hips": Vector3(0, 20, 0), "Spine": Vector3(-16, 18, 0), "Chest": Vector3(-6, 38, -4),
		"ArmR": AnimBuilder.limb(-60, 82, 10), "ForearmR": Vector3(12, 0, 0), "LegL": Vector3(36, 0, 8), "ShinL": Vector3(-30, 0, 0)}
	attack_clip(lib, &"combo_2", st, {
		"start": from2,
		"windup": {"Chest": Vector3(-8, 48, -6), "ArmR": AnimBuilder.limb(-85, 72, 30), "ForearmR": Vector3(75, 0, 0)},
		"strike": {"@Hips": Vector3(0, -0.1, 0), "Hips": Vector3(0, -28, 0), "Spine": Vector3(-10, -18, 0), "Chest": Vector3(-2, -40, 6),
			"ArmR": AnimBuilder.limb(110, 100, -30), "ForearmR": Vector3(6, 0, 0), "ArmL": AnimBuilder.limb(-30, 45),
			"LegR": Vector3(-30, 0, -8), "ShinR": Vector3(-30, 0, 0)},
		"follow": {"Chest": Vector3(-2, -48, 6), "ArmR": AnimBuilder.limb(125, 104, -30)},
	}, 0.22, 0.1, 0.6)
	var from3 := {"@Hips": Vector3(0, -0.1, 0), "Hips": Vector3(0, -28, 0), "Spine": Vector3(-10, -18, 0), "Chest": Vector3(-2, -40, 6),
		"ArmR": AnimBuilder.limb(115, 100, -30), "ForearmR": Vector3(6, 0, 0)}
	attack_clip(lib, &"combo_3", st, {
		"start": from3,
		"windup": {"@Hips": Vector3(0, 0.22, 0), "Hips": Vector3(0, -4, 0), "Spine": Vector3(14, 0, 0), "Chest": Vector3(10, 0, 0), "Head": Vector3(-8, 0, 0),
			"ArmR": AnimBuilder.limb(10, 170), "ForearmR": Vector3(70, 0, 0), "ArmL": AnimBuilder.limb(-30, 140), "ForearmL": Vector3(30, 0, 0),
			"LegR": Vector3(10, 0, 0), "ShinR": Vector3(-70, 0, 0), "LegL": Vector3(40, 0, 0), "ShinL": Vector3(-70, 0, 0), "^Body": Vector3(0.93, 1.1, 0.93)},
		"strike": {"@Hips": Vector3(0, -0.26, 0), "Hips": Vector3(0, 0, 0), "Spine": Vector3(-34, 0, 0), "Chest": Vector3(-16, 0, 0), "Head": Vector3(18, 0, 0),
			"ArmR": AnimBuilder.limb(0, 60), "ForearmR": Vector3(6, 0, 0), "ArmL": AnimBuilder.limb(-40, 50),
			"LegL": Vector3(50, 0, 6), "ShinL": Vector3(-56, 0, 0), "LegR": Vector3(-34, 0, -6), "ShinR": Vector3(-46, 0, 0), "^Body": Vector3(1.1, 0.88, 1.1)},
		"follow": {"@Hips": Vector3(0, -0.24, 0), "^Body": Vector3.ONE},
	}, 0.35, 0.12, 0.85)
	attack_clip(lib, &"lunge", st, {
		"windup": {"@Hips": Vector3(0, -0.22, 0.12), "Hips": Vector3(0, -20, 0), "Spine": Vector3(-30, -10, 0), "Chest": Vector3(-10, -16, 0), "Head": Vector3(20, 10, 0),
			"ArmR": AnimBuilder.limb(150, 60, -20), "ForearmR": Vector3(90, 0, 0), "ArmL": AnimBuilder.limb(-10, 70), "ForearmL": Vector3(20, 0, 0),
			"LegL": Vector3(40, 0, 6), "ShinL": Vector3(-70, 0, 0), "LegR": Vector3(-36, 0, -6), "ShinR": Vector3(-60, 0, 0), "^Body": Vector3(1.06, 0.92, 1.06)},
		"strike": {"@Hips": Vector3(0, -0.2, -0.1), "Hips": Vector3(0, 14, 0), "Spine": Vector3(-26, 10, 0), "Chest": Vector3(-8, 12, 0), "Head": Vector3(16, -10, 0),
			"ArmR": AnimBuilder.limb(0, 95, 0), "ForearmR": Vector3(0, 0, 0), "ArmL": AnimBuilder.limb(-150, 50),
			"LegL": Vector3(56, 0, 6), "ShinL": Vector3(-40, 0, 0), "LegR": Vector3(-48, 0, -6), "ShinR": Vector3(-10, 0, 0), "^Body": Vector3(0.94, 1.06, 0.94)},
		"follow": {"@Hips": Vector3(0, -0.2, -0.1), "^Body": Vector3.ONE},
	}, 0.5, 0.2, 0.7)
	sequence_clip(lib, &"evade", 0.38, st, [
		[0.15, {"@Hips": Vector3(0, -0.2, 0), "Spine": Vector3(-20, 0, 14), "LegR": Vector3(30, 0, -20), "ShinR": Vector3(-80, 0, 0), "LegL": Vector3(10, 0, 20), "ShinL": Vector3(-70, 0, 0),
			"^Body": Vector3(1.06, 0.92, 1.06)}, OUT],
		[0.45, {"@Hips": Vector3(0, 0.1, 0), "^Body": Vector3(0.95, 1.06, 0.95), "ShinR": Vector3(-50, 0, 0), "ShinL": Vector3(-50, 0, 0)}, OUT],
		[0.8, {"@Hips": Vector3(0, -0.16, 0), "^Body": Vector3(1.05, 0.94, 1.05)}, IN],
		[1.0, st, INOUT]], false, [[0.3, &"footstep"]])
	humanoid_reactions(lib, st, 1.0)
