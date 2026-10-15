extends SceneTree
## Samples the blade (trail base -> tip) of the hero's clips at 60 Hz in root space and
## writes JSON for plotting: godot --headless --script res://tests/visual/blade_trace.gd -- --out=/tmp/trace.json

func _initialize() -> void:
	var out := "/tmp/blade_trace.json"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
	_run.call_deferred(out)


func _run(out: String) -> void:
	var rig := HeroRig.new()
	rig.anim_map = load("res://resources/animation/hero_anim_map.tres")
	root.add_child(rig)
	var stats := load("res://resources/balance/player_stats.tres") as PlayerStats
	var table := {}
	for atk: AttackData in stats.light_attacks:
		table[atk.anim] = {"windup": atk.windup, "active": atk.active, "recovery": atk.recovery}
	var h := stats.heavy_attack
	table[&"heavy_windup"] = {"length": h.windup}
	table[&"heavy_release"] = {"windup": h.windup, "active": h.active, "recovery": h.recovery}
	rig.build(table)
	var ap := rig.get_animation_player()
	var data := {}
	for clip: StringName in [&"light_1", &"light_2", &"light_3", &"heavy_windup", &"heavy_release", &"idle", &"run", &"dodge"]:
		var anim := ap.get_animation(clip)
		var samples: Array = []
		ap.play(clip)
		var n := int(anim.length * 60.0)
		for i in n + 1:
			ap.seek(float(i) / 60.0, true)
			var base := (rig.get_socket(&"trail_base") as Node3D).global_position
			var tip := (rig.get_socket(&"trail_tip") as Node3D).global_position
			var hand := (rig.bones["HandR"] as Node3D).global_position
			samples.append([float(i) / 60.0, [base.x, base.y, base.z], [tip.x, tip.y, tip.z], [hand.x, hand.y, hand.z]])
		var t: Dictionary = table.get(clip, {})
		data[String(clip)] = {"samples": samples, "windup": t.get("windup", 0.0), "active": t.get("active", 0.0)}
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))
	f.close()
	print("blade_trace: wrote ", out)
	quit()
