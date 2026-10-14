class_name EnemyRig
extends PlaceholderRig
## Helpers shared by the enemy placeholder rigs: limb chains and a standard
## attack-clip layout (windup -> held anticipation -> snap strike -> follow-through)
## whose timings and events come from the EnemyAttackData of the owner.

const L := AnimBuilder.LINEAR
const IN := AnimBuilder.IN
const OUT := AnimBuilder.OUT
const SNAP := AnimBuilder.SNAP
const INOUT := AnimBuilder.INOUT
const BACK := AnimBuilder.BACK


func build_arm(side: String, parent: String, shoulder: Vector3, upper: float, fore: float, r: float, mat: Material, hand_mat: Material = null) -> void:
	add_bone("Arm" + side, parent, shoulder)
	part("Arm" + side, sphere(r * 1.3), mat)
	part("Arm" + side, capsule(r, upper + r), mat, Vector3(0, -upper * 0.5, 0))
	add_bone("Forearm" + side, "Arm" + side, Vector3(0, -upper, 0))
	part("Forearm" + side, capsule(r * 0.85, fore + r), mat, Vector3(0, -fore * 0.45, 0))
	add_bone("Hand" + side, "Forearm" + side, Vector3(0, -fore, 0))
	part("Hand" + side, box(Vector3(r * 1.3, r * 1.6, r * 1.4)), hand_mat if hand_mat != null else mat, Vector3(0, -r * 0.7, 0))


func build_leg(side: String, parent: String, hip: Vector3, thigh: float, shin: float, r: float, mat: Material, foot_mat: Material = null) -> void:
	add_bone("Leg" + side, parent, hip)
	part("Leg" + side, capsule(r, thigh + r), mat, Vector3(0, -thigh * 0.48, 0))
	add_bone("Shin" + side, "Leg" + side, Vector3(0, -thigh, 0))
	part("Shin" + side, capsule(r * 0.82, shin + r * 0.8), mat, Vector3(0, -shin * 0.48, 0))
	add_bone("Foot" + side, "Shin" + side, Vector3(0, -shin, 0))
	part("Foot" + side, box(Vector3(r * 1.3, r * 0.8, r * 2.8)), foot_mat if foot_mat != null else mat, Vector3(0, -r * 0.3, -r * 0.6))


static func merge(a: Dictionary, b: Dictionary) -> Dictionary:
	var r := a.duplicate()
	for k: Variant in b:
		r[k] = b[k]
	return r


## Builds a standard attack clip. `poses` keys: "start" (optional, combo entry pose), "windup",
## "hold" (optional), "strike", "follow" (optional). The clip always ends in `stance`.
func attack_clip(lib: AnimationLibrary, clip: StringName, stance: Dictionary, poses: Dictionary, def_w: float = 0.6, def_a: float = 0.12, def_r: float = 0.6) -> void:
	var tm: Dictionary = clip_table.get(clip, {})
	var w := float(tm.get("windup", def_w))
	var a := float(tm.get("active", def_a))
	var r := float(tm.get("recovery", def_r))
	var lead := float(tm.get("lead", w * 0.4))
	var b := AnimBuilder.new(self, clip, w + a + r)
	b.key(0.0, merge(stance, poses.get("start", {})))
	var wp: Dictionary = poses["windup"]
	b.key(w * 0.7, wp, OUT)
	b.key(w, merge(wp, poses.get("hold", {})), INOUT)
	b.key(w + a, poses["strike"], SNAP)
	if poses.has("follow"):
		b.key(w + a + r * 0.35, poses["follow"], OUT)
	b.key(w + a + r, stance, INOUT)
	b.event(maxf(w - lead, 0.017), &"telegraph")
	b.event(maxf(w * 0.92, 0.017), &"swing")
	b.event(maxf(w, 0.02), &"hitbox_on")
	b.event(w + a, &"hitbox_off")
	lib.add_animation(clip, b.build())


## Simple clip through a list of [time_fraction, pose, ease] plus [time, event] pairs.
func sequence_clip(lib: AnimationLibrary, clip: StringName, length: float, stance: Dictionary, keys: Array, loop: bool = false, events: Array = []) -> void:
	var b := AnimBuilder.new(self, clip, length, loop)
	b.key(0.0, stance)
	for k: Array in keys:
		b.key(float(k[0]) * length, k[1], int(k[2]) if k.size() > 2 else INOUT)
	b.events(events)
	lib.add_animation(clip, b.build())


## Generic humanoid reactions: alert, hit, stagger, death (bones missing on a rig are skipped).
func humanoid_reactions(lib: AnimationLibrary, stance: Dictionary, heavy: float = 1.0) -> void:
	sequence_clip(lib, &"alert", 0.8, stance, [
		[0.2, {"Neck": Vector3(-14, 0, 0), "Head": Vector3(-16, 0, 0), "Chest": Vector3(8, 0, 0),
			"ArmR": AnimBuilder.limb(70, 50), "ArmL": AnimBuilder.limb(-70, 50), "ForearmR": Vector3(50, 0, 0), "ForearmL": Vector3(50, 0, 0),
			"^Body": Vector3(0.96, 1.05, 0.96)}, OUT],
		[0.55, merge({}, {"^Body": Vector3.ONE}), INOUT],
		[1.0, stance, INOUT]])
	var hl := clip_length(&"hit", 0.3)
	sequence_clip(lib, &"hit", hl, stance, [
		[0.2, {"@Hips": Vector3(0, -0.06, 0.06), "Spine": Vector3(16 * heavy, 0, 5), "Chest": Vector3(10, -12, 0), "Head": Vector3(18, 10, 0),
			"ArmR": AnimBuilder.limb(80, 40), "ArmL": AnimBuilder.limb(-80, 40), "^Body": Vector3(1.04, 0.95, 1.04)}, SNAP],
		[1.0, stance, INOUT]])
	var sl := clip_length(&"stagger", 2.0)
	sequence_clip(lib, &"stagger", sl, stance, [
		[0.08, {"@Hips": Vector3(0, -0.18, 0.15), "Hips": Vector3(14, 0, 0), "Spine": Vector3(26, 0, 10), "Chest": Vector3(16, 14, 0), "Head": Vector3(28, -10, 8),
			"ArmR": AnimBuilder.limb(110, 70), "ForearmR": Vector3(20, 0, 0), "ArmL": AnimBuilder.limb(-110, 75), "ForearmL": Vector3(20, 0, 0),
			"LegR": Vector3(-10, 0, 0), "ShinR": Vector3(-50, 0, 0), "LegL": Vector3(30, 0, 0), "ShinL": Vector3(-40, 0, 0),
			"^Body": Vector3(1.06, 0.92, 1.06)}, SNAP],
		[0.3, {"@Hips": Vector3(0, -0.3, 0.1), "Spine": Vector3(-30, 0, -6), "Chest": Vector3(-14, -10, 0), "Head": Vector3(20, 0, -10),
			"ArmR": AnimBuilder.limb(40, 25), "ArmL": AnimBuilder.limb(-30, 30), "LegR": Vector3(40, 0, 0), "ShinR": Vector3(-80, 0, 0),
			"LegL": Vector3(-10, 0, 0), "ShinL": Vector3(-70, 0, 0), "^Body": Vector3.ONE}, INOUT],
		[0.75, {"@Hips": Vector3(0, -0.24, 0.05), "Spine": Vector3(-24, 0, 6), "Head": Vector3(10, 0, 8)}, INOUT],
		[1.0, stance, INOUT]])
	sequence_clip(lib, &"death", 1.5, stance, [
		[0.15, {"@Hips": Vector3(0, -0.1, 0.1), "Spine": Vector3(22, 0, 8), "Head": Vector3(30, 0, 0),
			"ArmR": AnimBuilder.limb(90, 60), "ArmL": AnimBuilder.limb(-90, 60)}, SNAP],
		[0.5, {"@Hips": Vector3(0, -0.5, 0), "Hips": Vector3(-8, 0, 0), "Spine": Vector3(-30, 0, 0), "Head": Vector3(-20, 0, 0),
			"LegR": Vector3(80, 0, 0), "ShinR": Vector3(-120, 0, 0), "LegL": Vector3(70, 0, 10), "ShinL": Vector3(-120, 0, 0),
			"ArmR": AnimBuilder.limb(20, 30), "ArmL": AnimBuilder.limb(-20, 30)}, IN],
		[0.82, {"@Hips": Vector3(0, -0.8, -0.3), "Hips": Vector3(-84, 0, 6), "Spine": Vector3(-5, 0, 0), "Chest": Vector3.ZERO, "Head": Vector3(10, 30, 0),
			"LegR": Vector3(10, 0, 0), "ShinR": Vector3(-20, 0, 0), "LegL": Vector3(14, 0, 10), "ShinL": Vector3(-30, 0, 0),
			"ArmR": AnimBuilder.limb(60, 150), "ArmL": AnimBuilder.limb(-60, 120)}, IN],
		[1.0, {"@Hips": Vector3(0, -0.78, -0.3)}, OUT]])


func clip_length(clip: StringName, fallback: float) -> float:
	return float(clip_table.get(clip, {}).get("length", fallback))
