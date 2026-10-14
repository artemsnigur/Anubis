class_name ScarabRig
extends EnemyRig
## Scarab: iridescent dark-teal beetle with gold seams, snapping mandibles and six
## legs moving in an alternating tripod gait. Flips onto its back when staggered.

const LEGS := ["FR", "MR", "BR", "FL", "ML", "BL"]
const TRIPOD_A := ["FR", "BR", "ML"]


func _build_body() -> void:
	var shell := Mats.get_mat(&"scarab")
	var gold := Mats.get_mat(&"gold")
	var black := Mats.get_mat(&"black_glaze")
	add_bone("Body", "", Vector3.ZERO)
	add_bone("Hips", "Body", Vector3(0, 0.34, 0))
	part("Hips", sphere(0.32, 0.64, 16), shell, Vector3(0, 0.02, 0.05), Vector3.ZERO, Vector3(0.95, 0.55, 1.2))
	part("Hips", box(Vector3(0.025, 0.04, 0.7)), gold, Vector3(0, 0.19, 0.05))
	part("Hips", sphere(0.26, 0.52, 12), black, Vector3(0, -0.06, 0.05), Vector3.ZERO, Vector3(0.9, 0.4, 1.1))
	add_bone("Thorax", "Hips", Vector3(0, 0.0, -0.36))
	part("Thorax", sphere(0.2, 0.4, 12), shell, Vector3(0, 0.02, 0), Vector3.ZERO, Vector3(1.15, 0.6, 0.8))
	part("Thorax", box(Vector3(0.36, 0.03, 0.03)), gold, Vector3(0, 0.08, 0.1))
	add_bone("Head", "Thorax", Vector3(0, -0.02, -0.18))
	part("Head", box(Vector3(0.24, 0.1, 0.14)), black, Vector3(0, 0, -0.04))
	part("Head", box(Vector3(0.05, 0.03, 0.03)), Mats.get_mat(&"eye_gold"), Vector3(0.09, 0.04, -0.1))
	part("Head", box(Vector3(0.05, 0.03, 0.03)), Mats.get_mat(&"eye_gold"), Vector3(-0.09, 0.04, -0.1))
	for sx: float in [1.0, -1.0]:
		var mn := "Mand" + ("R" if sx > 0.0 else "L")
		add_bone(mn, "Head", Vector3(0.07 * sx, -0.02, -0.1))
		part(mn, prism(Vector3(0.05, 0.03, 0.18)), gold, Vector3(-0.02 * sx, 0, -0.08), Vector3(90, 0, 0))
	var leg_pos := {"FR": Vector3(0.16, -0.06, -0.38), "MR": Vector3(0.24, -0.06, -0.05), "BR": Vector3(0.22, -0.06, 0.25),
		"FL": Vector3(-0.16, -0.06, -0.38), "ML": Vector3(-0.24, -0.06, -0.05), "BL": Vector3(-0.22, -0.06, 0.25)}
	for leg: String in LEGS:
		var sx := 1.0 if leg.ends_with("R") else -1.0
		add_bone("Leg" + leg, "Hips", leg_pos[leg])
		part("Leg" + leg, capsule(0.028, 0.3), black, Vector3(0.12 * sx, 0.02, 0), Vector3(0, 0, 80 * sx))
		add_bone("Shin" + leg, "Leg" + leg, Vector3(0.24 * sx, 0.04, 0))
		part("Shin" + leg, capsule(0.022, 0.34), black, Vector3(0.03 * sx, -0.14, 0), Vector3(0, 0, 15 * sx))
	add_socket(&"weapon_tip", "Head", Vector3(0, 0.02, -0.25))
	add_socket(&"head", "Head", Vector3(0, 0.1, -0.1))


func _stance() -> Dictionary:
	var d := {"@Hips": Vector3.ZERO, "Hips": Vector3.ZERO, "Thorax": Vector3.ZERO, "Head": Vector3.ZERO,
		"MandR": Vector3(0, 10, 0), "MandL": Vector3(0, -10, 0), "^Body": Vector3.ONE}
	for leg: String in LEGS:
		d["Leg" + leg] = Vector3.ZERO
		d["Shin" + leg] = Vector3.ZERO
	return d


## Tripod gait pose: `swing` in -1..1 (which tripod is forward).
func _gait(swing: float, lift_a: float, lift_b: float) -> Dictionary:
	var d := {}
	for leg: String in LEGS:
		var a := TRIPOD_A.has(leg)
		var s := swing if a else -swing
		var sx := 1.0 if leg.ends_with("R") else -1.0
		var lift := lift_a if a else lift_b
		d["Leg" + leg] = Vector3(0, s * 28.0 * sx, lift * 30.0 * sx)
	return d


func _build_clips(lib: AnimationLibrary) -> void:
	var st := _stance()
	sequence_clip(lib, &"idle", 1.4, st, [
		[0.3, {"MandR": Vector3(0, -15, 0), "MandL": Vector3(0, 15, 0), "Head": Vector3(0, 8, 0)}],
		[0.45, {"MandR": Vector3(0, 10, 0), "MandL": Vector3(0, -10, 0)}],
		[0.7, {"Head": Vector3(0, -8, 0), "@Hips": Vector3(0, -0.02, 0)}]], true)
	for spec in [[&"walk", 0.4], [&"run", 0.24]]:
		var clip: StringName = spec[0]
		var len_s: float = spec[1]
		var b := AnimBuilder.new(self, clip, len_s, true)
		b.key(0.0, merge(st, _gait(1.0, 0.0, 0.0)), L)
		b.key(len_s * 0.25, merge(_gait(0.0, 0.0, 1.0), {"@Hips": Vector3(0, 0.03, 0)}), L)
		b.key(len_s * 0.5, merge(_gait(-1.0, 0.0, 0.0), {"@Hips": Vector3(0, 0.0, 0)}), L)
		b.key(len_s * 0.75, merge(_gait(0.0, 1.0, 0.0), {"@Hips": Vector3(0, 0.03, 0)}), L)
		lib.add_animation(clip, b.build())
	attack_clip(lib, &"bite", st, {
		"windup": {"Hips": Vector3(22, 0, 0), "Thorax": Vector3(10, 0, 0), "Head": Vector3(14, 0, 0), "@Hips": Vector3(0, 0.08, 0.1),
			"MandR": Vector3(0, -45, 0), "MandL": Vector3(0, 45, 0), "^Body": Vector3(0.95, 1.1, 0.95)},
		"hold": {"Hips": Vector3(26, 0, 0), "MandR": Vector3(0, -55, 0), "MandL": Vector3(0, 55, 0)},
		"strike": {"Hips": Vector3(-14, 0, 0), "Thorax": Vector3(-8, 0, 0), "Head": Vector3(-10, 0, 0), "@Hips": Vector3(0, -0.06, -0.1),
			"MandR": Vector3(0, 18, 0), "MandL": Vector3(0, -18, 0), "^Body": Vector3(1.08, 0.9, 1.15)},
		"follow": {"Hips": Vector3(-8, 0, 0), "^Body": Vector3.ONE},
	}, 0.42, 0.16, 0.55)
	sequence_clip(lib, &"alert", 0.5, st, [
		[0.3, {"Hips": Vector3(18, 0, 0), "MandR": Vector3(0, -40, 0), "MandL": Vector3(0, 40, 0), "@Hips": Vector3(0, 0.06, 0)}, OUT],
		[0.6, {"MandR": Vector3(0, 15, 0), "MandL": Vector3(0, -15, 0)}, SNAP],
		[1.0, st, INOUT]])
	sequence_clip(lib, &"hit", clip_length(&"hit", 0.25), st, [
		[0.25, {"Hips": Vector3(10, 0, 8), "@Hips": Vector3(0, 0.05, 0.08), "^Body": Vector3(1.1, 0.85, 1.1)}, SNAP],
		[1.0, st, INOUT]])
	var flipped := merge(_gait(0.0, 1.0, 1.0), {"Hips": Vector3(0, 0, 180), "@Hips": Vector3(0, 0.0, 0), "MandR": Vector3(0, -40, 0), "MandL": Vector3(0, 40, 0)})
	var flail := merge(_gait(1.0, 0.6, 1.2), {"Hips": Vector3(0, 20, 176)})
	sequence_clip(lib, &"stagger", clip_length(&"stagger", 1.0), st, [
		[0.12, merge(flipped, {"@Hips": Vector3(0, 0.3, 0)}), OUT],
		[0.25, flipped, IN],
		[0.4, flail, INOUT], [0.55, flipped, INOUT], [0.7, flail, INOUT],
		[0.85, merge(flipped, {"@Hips": Vector3(0, 0.25, 0)}), INOUT],
		[1.0, st, IN]])
	sequence_clip(lib, &"death", 1.2, st, [
		[0.2, merge(flipped, {"@Hips": Vector3(0, 0.3, 0)}), OUT],
		[0.4, flipped, IN],
		[1.0, merge(_gait(0.0, -1.5, -1.5), {"Hips": Vector3(0, 30, 180)}), INOUT]])
