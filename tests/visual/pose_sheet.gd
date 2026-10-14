extends Node3D
## Visual check: renders a grid of rig copies, each frozen at a frame of a clip.
## godot res://tests/visual/pose_sheet.tscn -- --rig=hero --clips=idle,light_1 --cols=6 --out=/tmp/poses
## Each clip gets one row with `cols` evenly spaced frames.

const RIGS := {
	"hero": ["res://scripts/rigs/hero_rig.gd", "res://resources/animation/hero_anim_map.tres", ""],
	"mummy": ["res://scripts/rigs/mummy_rig.gd", "res://resources/animation/mummy_anim_map.tres", "res://resources/enemies/mummy.tres"],
	"jackal": ["res://scripts/rigs/jackal_rig.gd", "res://resources/animation/jackal_anim_map.tres", "res://resources/enemies/jackal.tres"],
	"cobra": ["res://scripts/rigs/cobra_rig.gd", "res://resources/animation/cobra_anim_map.tres", "res://resources/enemies/cobra.tres"],
	"scarab": ["res://scripts/rigs/scarab_rig.gd", "res://resources/animation/scarab_anim_map.tres", "res://resources/enemies/scarab.tres"],
	"ammit": ["res://scripts/rigs/ammit_rig.gd", "res://resources/animation/ammit_anim_map.tres", "res://resources/enemies/ammit.tres"],
}

var _args: Dictionary = {}
var _frame: int = 0


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--") and a.contains("="):
			var kv := a.substr(2).split("=", true, 1)
			_args[kv[0]] = kv[1]
	var rig_key: String = _args.get("rig", "hero")
	var clips: PackedStringArray = String(_args.get("clips", "idle")).split(",")
	var cols := int(_args.get("cols", "6"))
	var spacing := float(_args.get("spacing", "1.6"))
	var yaw := float(_args.get("yaw", "-35"))
	var table := _clip_table(rig_key)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.18, 0.2, 0.26)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.6, 0.6, 0.65)
	e.ambient_light_energy = 0.8
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	sun.light_energy = 1.4
	add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 80)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.45, 0.4, 0.35)
	floor_mi.material_override = fm
	add_child(floor_mi)
	var rows := clips.size()
	for r in rows:
		var parts := clips[r].split("@")
		var clip := StringName(parts[0])
		for c in cols:
			var rig: PlaceholderRig = (load(RIGS[rig_key][0]) as GDScript).new()
			rig.anim_map = load(RIGS[rig_key][1])
			add_child(rig)
			rig.position = Vector3((c - (cols - 1) * 0.5) * spacing, (float(rows - 1) * 0.5 - r) * 2.3, 0)
			rig.rotation_degrees = Vector3(0, 180.0 + yaw, 0)
			rig.build(table)
			var ap := rig.get_animation_player()
			if not ap.has_animation(clip):
				push_warning("missing clip %s" % clip)
				continue
			var length := ap.get_animation(clip).length
			var t := length * float(c) / float(maxi(cols - 1, 1))
			if parts.size() > 1:
				t = float(parts[1]) + float(c) * 0.03
			ap.play(clip)
			ap.seek(t, true)
			ap.pause()
	var cam := Camera3D.new()
	var w := cols * spacing
	var h := rows * 2.3
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(h + 2.0, w * 9.0 / 16.0 + 1.0)
	cam.rotation_degrees = Vector3(float(_args.get("pitch", "-12")), 0, 0)
	cam.position = Vector3(0, 1.0 + 20.0 * sin(deg_to_rad(-cam.rotation_degrees.x)), 20.0 * cos(deg_to_rad(-cam.rotation_degrees.x)))
	floor_mi.visible = false
	add_child(cam)
	cam.make_current()


func _clip_table(rig_key: String) -> Dictionary:
	var data_path: String = RIGS[rig_key][2]
	if data_path != "":
		var data := load(data_path) as EnemyData
		var et := {}
		var stack: Array = data.attacks.duplicate()
		while not stack.is_empty():
			var a := stack.pop_back() as EnemyAttackData
			if a == null or et.has(a.anim):
				continue
			et[a.anim] = {"windup": a.windup, "active": a.active, "recovery": a.recovery, "lead": a.telegraph_lead}
			if a.combo_next != null:
				stack.append(a.combo_next)
			if a.combo_next_phase2 != null:
				stack.append(a.combo_next_phase2)
		et[&"hit"] = {"length": maxf(data.flinch_duration, 0.2)}
		et[&"stagger"] = {"length": data.stagger_duration}
		return et
	var s := GameState.player_stats
	var t := {}
	for a: AttackData in s.light_attacks:
		t[a.anim] = {"windup": a.windup, "active": a.active, "recovery": a.recovery}
	var h := s.heavy_attack
	t[&"heavy_windup"] = {"length": h.windup}
	t[&"heavy_release"] = {"windup": h.windup, "active": h.active, "recovery": h.recovery}
	var ra := s.ranged_attack
	t[&"cast"] = {"windup": ra.windup, "active": ra.active, "recovery": ra.recovery}
	t[&"dodge"] = {"length": s.dodge_duration}
	t[&"heal"] = {"length": s.heal_duration, "apply": s.heal_apply_time}
	return t


func _process(_delta: float) -> void:
	_frame += 1
	if _frame == 12:
		var img := get_viewport().get_texture().get_image()
		img.save_png(String(_args.get("out", "/tmp/poses")) + ".png")
		get_tree().quit()
