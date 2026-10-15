extends SceneTree
## Dev tool: writes the DEFAULT balance resources (.tres) into res://resources/.
## WARNING: overwrites the files. After generation the .tres files are the source of
## truth - tweak them in the inspector, not here (unless you want to reset defaults).
## Run: godot --headless --script res://tools/generate_resources.gd

const R := "res://resources/"


func _init() -> void:
	for d in ["attacks", "enemies", "balance", "animation"]:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(R + d))
	_balance()
	_player()
	_enemies()
	_anim_maps()
	print("generate_resources: done")
	quit(0)


func _save(res: Resource, path: String) -> void:
	var err := ResourceSaver.save(res, R + path)
	if err != OK:
		push_error("generate_resources: failed to save %s (%s)" % [path, error_string(err)])


func _atk(id: String, anim: String, windup: float, active: float, recovery: float, damage: float, poise: float, knockback: float) -> AttackData:
	var a := AttackData.new()
	a.id = StringName(id)
	a.anim = StringName(anim)
	a.windup = windup
	a.active = active
	a.recovery = recovery
	a.damage = damage
	a.poise_damage = poise
	a.knockback = knockback
	return a


func _eatk(id: String, anim: String, windup: float, active: float, recovery: float, damage: float, knockback: float, range_min: float, range_max: float) -> EnemyAttackData:
	var a := EnemyAttackData.new()
	a.id = StringName(id)
	a.anim = StringName(anim)
	a.windup = windup
	a.active = active
	a.recovery = recovery
	a.damage = damage
	a.poise_damage = 0.0
	a.knockback = knockback
	a.range_min = range_min
	a.range_max = range_max
	a.stamina_cost = 0.0
	a.energy_gain = 0.0
	a.lunge_distance = 0.0
	return a


func _balance() -> void:
	var b := BalanceConfig.new()
	_save(b, "balance/balance.tres")
	var l := LevelingConfig.new()
	_save(l, "balance/leveling.tres")


func _player() -> void:
	var l1 := _atk("light_1", "light_1", 0.11, 0.08, 0.20, 14.0, 12.0, 2.5)
	l1.hitstop = 0.055
	l1.shake = 0.16
	l1.stamina_cost = 12.0
	l1.energy_gain = 0.25
	l1.lunge_distance = 0.55
	l1.hitbox_size = Vector3(2.5, 1.4, 1.9)
	l1.hitbox_forward = 1.05
	l1.chain_delay = 0.04
	_save(l1, "attacks/player_light_1.tres")

	var l2 := _atk("light_2", "light_2", 0.11, 0.08, 0.20, 14.0, 12.0, 2.5)
	l2.hitstop = 0.06
	l2.shake = 0.18
	l2.stamina_cost = 12.0
	l2.energy_gain = 0.25
	l2.lunge_distance = 0.55
	l2.hitbox_size = Vector3(2.5, 1.4, 1.9)
	l2.hitbox_forward = 1.05
	l2.chain_delay = 0.04
	_save(l2, "attacks/player_light_2.tres")

	var l3 := _atk("light_3", "light_3", 0.16, 0.08, 0.35, 22.0, 22.0, 5.5)
	l3.hitstop = 0.08
	l3.shake = 0.3
	l3.stamina_cost = 16.0
	l3.energy_gain = 0.4
	l3.lunge_distance = 0.9
	l3.hitbox_size = Vector3(2.7, 1.5, 2.2)
	l3.hitbox_forward = 1.2
	l3.chain_delay = 0.12
	_save(l3, "attacks/player_light_3.tres")

	var hv := _atk("heavy", "heavy_release", 0.40, 0.12, 0.45, 32.0, 36.0, 7.0)
	hv.hitstop = 0.09
	hv.shake = 0.45
	hv.stamina_cost = 28.0
	hv.energy_gain = 0.5
	hv.is_heavy = true
	hv.lunge_distance = 1.1
	hv.hitbox_size = Vector3(2.9, 1.6, 2.5)
	hv.hitbox_forward = 1.3
	hv.chain_delay = 0.2
	hv.cancel_delay = 0.12
	_save(hv, "attacks/player_heavy.tres")

	var ra := _atk("eye_of_ra", "cast", 0.18, 0.05, 0.30, 38.0, 25.0, 4.0)
	ra.hitstop = 0.06
	ra.shake = 0.22
	ra.stamina_cost = 0.0
	ra.energy_gain = 0.0
	ra.lunge_distance = 0.0
	ra.cancel_delay = 0.1
	_save(ra, "attacks/player_eye_of_ra.tres")

	var ps := PlayerStats.new()
	ps.light_attacks.assign([load(R + "attacks/player_light_1.tres"), load(R + "attacks/player_light_2.tres"), load(R + "attacks/player_light_3.tres")])
	ps.heavy_attack = load(R + "attacks/player_heavy.tres")
	ps.ranged_attack = load(R + "attacks/player_eye_of_ra.tres")
	_save(ps, "balance/player_stats.tres")


func _enemies() -> void:
	# --- Mummy Guardian -----------------------------------------------------------
	var slam := _eatk("mummy_slam", "slam", 0.95, 0.15, 0.9, 26.0, 6.0, 0.0, 2.5)
	slam.hitstop = 0.09
	slam.shake = 0.5
	slam.angle_max = 60.0
	slam.cooldown = 2.2
	slam.weight = 2.0
	slam.telegraph_lead = 0.38
	slam.tracking_deg = 150.0
	slam.move_type = EnemyAttackData.MoveType.LUNGE
	slam.move_speed = 3.5
	slam.move_duration = 0.15
	slam.hitbox_size = Vector3(2.0, 1.8, 2.2)
	slam.hitbox_forward = 1.3
	_save(slam, "attacks/mummy_slam.tres")

	var grab := _eatk("mummy_grab", "grab", 0.85, 0.22, 1.0, 34.0, 8.0, 0.0, 2.1)
	grab.hitstop = 0.05
	grab.shake = 0.35
	grab.angle_max = 50.0
	grab.cooldown = 7.0
	grab.weight = 1.0
	grab.telegraph = EnemyAttackData.Telegraph.FLASH
	grab.telegraph_lead = 0.24
	grab.tracking_deg = 180.0
	grab.move_type = EnemyAttackData.MoveType.GRAB
	grab.move_speed = 5.0
	grab.move_duration = 0.2
	grab.hitbox_size = Vector3(1.6, 1.6, 1.8)
	grab.hitbox_forward = 1.0
	_save(grab, "attacks/mummy_grab.tres")

	var mummy := EnemyData.new()
	mummy.display_name = "Mummy Guardian"
	mummy.max_hp = 130.0
	mummy.max_poise = 70.0
	mummy.poise_regen_delay = 3.0
	mummy.poise_regen_rate = 20.0
	mummy.stagger_duration = 2.2
	mummy.flinch_duration = 0.3
	mummy.knockback_resist = 0.6
	mummy.hyper_armor = true
	mummy.ka_reward = 60
	mummy.walk_speed = 1.5
	mummy.run_speed = 2.4
	mummy.acceleration = 10.0
	mummy.turn_speed_deg = 200.0
	mummy.detect_radius = 9.0
	mummy.lose_radius = 20.0
	mummy.leash_radius = 24.0
	mummy.alert_time = 0.8
	mummy.strafe_radius = 3.0
	mummy.strafe_speed = 1.0
	mummy.think_interval = 0.3
	mummy.attacks.assign([load(R + "attacks/mummy_slam.tres"), load(R + "attacks/mummy_grab.tres")])
	_save(mummy, "enemies/mummy.tres")

	# --- Scarab -----------------------------------------------------------------
	var bite := _eatk("scarab_bite", "bite", 0.42, 0.16, 0.55, 7.0, 2.0, 0.0, 3.6)
	bite.hitstop = 0.04
	bite.shake = 0.1
	bite.angle_max = 50.0
	bite.cooldown = 1.4
	bite.telegraph_lead = 0.26
	bite.tracking_deg = 420.0
	bite.move_type = EnemyAttackData.MoveType.LUNGE
	bite.move_speed = 15.0
	bite.move_duration = 0.18
	bite.hitbox_size = Vector3(0.9, 0.8, 1.0)
	bite.hitbox_forward = 0.5
	bite.hitbox_height = 0.35
	_save(bite, "attacks/scarab_bite.tres")

	var scarab := EnemyData.new()
	scarab.display_name = "Scarab"
	scarab.max_hp = 18.0
	scarab.max_poise = 4.0
	scarab.stagger_duration = 1.0
	scarab.flinch_duration = 0.25
	scarab.ka_reward = 10
	scarab.walk_speed = 3.0
	scarab.run_speed = 6.0
	scarab.acceleration = 40.0
	scarab.turn_speed_deg = 720.0
	scarab.detect_radius = 10.0
	scarab.lose_radius = 22.0
	scarab.alert_time = 0.3
	scarab.strafe_radius = 2.8
	scarab.strafe_speed = 4.0
	scarab.think_interval = 0.15
	scarab.attacks.assign([load(R + "attacks/scarab_bite.tres")])
	_save(scarab, "enemies/scarab.tres")

	# --- Jackal Warrior -----------------------------------------------------------
	var c3 := _eatk("jackal_combo_3", "combo_3", 0.35, 0.12, 0.85, 18.0, 6.0, 0.0, 2.8)
	c3.hitstop = 0.08
	c3.shake = 0.35
	c3.telegraph_lead = 0.25
	c3.tracking_deg = 260.0
	c3.move_speed = 9.0
	c3.move_duration = 0.18
	c3.hitbox_size = Vector3(2.4, 1.4, 2.0)
	c3.hitbox_forward = 1.1
	_save(c3, "attacks/jackal_combo_3.tres")

	var c2 := _eatk("jackal_combo_2", "combo_2", 0.22, 0.1, 0.6, 11.0, 2.5, 0.0, 2.8)
	c2.hitstop = 0.06
	c2.telegraph_lead = 0.18
	c2.tracking_deg = 300.0
	c2.move_speed = 6.0
	c2.move_duration = 0.12
	c2.hitbox_size = Vector3(2.2, 1.4, 1.8)
	c2.hitbox_forward = 1.0
	c2.combo_next = load(R + "attacks/jackal_combo_3.tres")
	c2.combo_gap = 0.14
	_save(c2, "attacks/jackal_combo_2.tres")

	var c1 := _eatk("jackal_combo_1", "combo_1", 0.45, 0.1, 0.6, 11.0, 2.5, 0.0, 2.8)
	c1.hitstop = 0.06
	c1.angle_max = 70.0
	c1.cooldown = 3.0
	c1.weight = 2.0
	c1.telegraph_lead = 0.3
	c1.tracking_deg = 300.0
	c1.move_speed = 7.0
	c1.move_duration = 0.15
	c1.hitbox_size = Vector3(2.2, 1.4, 1.8)
	c1.hitbox_forward = 1.0
	c1.combo_next = load(R + "attacks/jackal_combo_2.tres")
	c1.combo_gap = 0.12
	_save(c1, "attacks/jackal_combo_1.tres")

	var jl := _eatk("jackal_lunge", "lunge", 0.5, 0.2, 0.7, 15.0, 5.0, 3.5, 7.5)
	jl.hitstop = 0.07
	jl.shake = 0.25
	jl.angle_max = 40.0
	jl.cooldown = 4.0
	jl.telegraph_lead = 0.3
	jl.tracking_deg = 220.0
	jl.move_speed = 17.0
	jl.move_duration = 0.24
	jl.hitbox_size = Vector3(1.8, 1.4, 2.0)
	jl.hitbox_forward = 0.9
	_save(jl, "attacks/jackal_lunge.tres")

	var jackal := EnemyData.new()
	jackal.display_name = "Jackal Warrior"
	jackal.max_hp = 80.0
	jackal.max_poise = 38.0
	jackal.stagger_duration = 1.8
	jackal.flinch_duration = 0.25
	jackal.knockback_resist = 0.2
	jackal.ka_reward = 70
	jackal.walk_speed = 2.4
	jackal.run_speed = 5.2
	jackal.acceleration = 25.0
	jackal.turn_speed_deg = 540.0
	jackal.detect_radius = 11.0
	jackal.lose_radius = 22.0
	jackal.alert_time = 0.4
	jackal.strafe_radius = 3.6
	jackal.strafe_speed = 2.6
	jackal.evade_chance = 0.35
	jackal.evade_cooldown = 2.5
	jackal.think_interval = 0.2
	jackal.attacks.assign([load(R + "attacks/jackal_combo_1.tres"), load(R + "attacks/jackal_lunge.tres")])
	_save(jackal, "enemies/jackal.tres")

	# --- Cobra Priestess ----------------------------------------------------------
	var spit := _eatk("cobra_spit", "spit", 0.85, 0.08, 0.6, 14.0, 1.5, 3.0, 13.0)
	spit.hitstop = 0.05
	spit.shake = 0.15
	spit.angle_max = 40.0
	spit.cooldown = 2.6
	spit.weight = 3.0
	spit.telegraph_lead = 0.4
	spit.tracking_deg = 200.0
	spit.move_type = EnemyAttackData.MoveType.PROJECTILE
	spit.move_speed = 11.0
	_save(spit, "attacks/cobra_spit.tres")

	var swipe := _eatk("cobra_swipe", "swipe", 0.5, 0.14, 0.6, 10.0, 7.0, 0.0, 2.3)
	swipe.hitstop = 0.06
	swipe.angle_max = 360.0
	swipe.cooldown = 4.0
	swipe.telegraph = EnemyAttackData.Telegraph.FLASH
	swipe.telegraph_lead = 0.25
	swipe.move_type = EnemyAttackData.MoveType.SPIN
	swipe.hitbox_size = Vector3(4.2, 1.0, 4.2)
	swipe.hitbox_forward = 0.0
	swipe.hitbox_height = 0.4
	_save(swipe, "attacks/cobra_swipe.tres")

	var cobra := EnemyData.new()
	cobra.display_name = "Cobra Priestess"
	cobra.max_hp = 55.0
	cobra.max_poise = 22.0
	cobra.stagger_duration = 1.8
	cobra.flinch_duration = 0.3
	cobra.ka_reward = 65
	cobra.walk_speed = 1.8
	cobra.run_speed = 3.6
	cobra.acceleration = 14.0
	cobra.turn_speed_deg = 300.0
	cobra.detect_radius = 13.0
	cobra.lose_radius = 24.0
	cobra.alert_time = 0.5
	cobra.strafe_radius = 7.0
	cobra.strafe_speed = 1.6
	cobra.retreat_radius = 4.5
	cobra.think_interval = 0.25
	cobra.attacks.assign([load(R + "attacks/cobra_spit.tres"), load(R + "attacks/cobra_swipe.tres")])
	_save(cobra, "enemies/cobra.tres")

	# --- Ammit ------------------------------------------------------------------
	var charge := _eatk("ammit_charge", "charge", 0.95, 2.0, 0.9, 30.0, 10.0, 6.0, 24.0)
	charge.hitstop = 0.1
	charge.shake = 0.6
	charge.angle_max = 120.0
	charge.cooldown = 6.0
	charge.weight = 2.0
	charge.telegraph_lead = 0.4
	charge.tracking_deg = 160.0
	charge.move_type = EnemyAttackData.MoveType.CHARGE
	charge.move_speed = 11.5
	charge.charge_turn_deg = 75.0
	charge.hitbox_size = Vector3(3.0, 2.2, 2.4)
	charge.hitbox_forward = 2.6
	charge.hitbox_height = 1.2
	_save(charge, "attacks/ammit_charge.tres")

	var tail := _eatk("ammit_tail", "tail", 0.75, 0.3, 0.75, 28.0, 9.0, 0.0, 6.0)
	tail.hitstop = 0.09
	tail.shake = 0.5
	tail.angle_max = 360.0
	tail.cooldown = 4.0
	tail.weight = 2.0
	tail.telegraph = EnemyAttackData.Telegraph.FLASH
	tail.telegraph_lead = 0.35
	tail.tracking_deg = 60.0
	tail.move_type = EnemyAttackData.MoveType.SPIN
	tail.hitbox_size = Vector3(10.5, 1.6, 10.5)
	tail.hitbox_forward = 0.0
	tail.hitbox_height = 0.8
	_save(tail, "attacks/ammit_tail.tres")

	var snap2 := _eatk("ammit_snap_2", "snap_2", 0.35, 0.12, 0.9, 26.0, 5.0, 0.0, 5.0)
	snap2.hitstop = 0.08
	snap2.shake = 0.4
	snap2.telegraph_lead = 0.22
	snap2.tracking_deg = 200.0
	snap2.move_speed = 9.0
	snap2.move_duration = 0.22
	snap2.hitbox_size = Vector3(2.4, 1.8, 2.6)
	snap2.hitbox_forward = 3.2
	snap2.hitbox_height = 1.1
	snap2.combo_next_phase2 = load(R + "attacks/ammit_tail.tres")
	snap2.combo_gap = 0.2
	_save(snap2, "attacks/ammit_snap_2.tres")

	var snap1 := _eatk("ammit_snap_1", "snap_1", 0.55, 0.12, 0.9, 24.0, 4.0, 0.0, 5.0)
	snap1.hitstop = 0.08
	snap1.shake = 0.35
	snap1.angle_max = 70.0
	snap1.cooldown = 2.5
	snap1.weight = 3.0
	snap1.telegraph_lead = 0.3
	snap1.tracking_deg = 200.0
	snap1.move_speed = 7.0
	snap1.move_duration = 0.2
	snap1.hitbox_size = Vector3(2.4, 1.8, 2.6)
	snap1.hitbox_forward = 3.2
	snap1.hitbox_height = 1.1
	snap1.combo_next = load(R + "attacks/ammit_snap_2.tres")
	snap1.combo_gap = 0.3
	_save(snap1, "attacks/ammit_snap_1.tres")

	var leap := _eatk("ammit_leap", "leap", 0.8, 0.7, 1.1, 32.0, 10.0, 5.0, 16.0)
	leap.hitstop = 0.1
	leap.shake = 0.8
	leap.angle_max = 140.0
	leap.cooldown = 7.0
	leap.weight = 1.5
	leap.telegraph = EnemyAttackData.Telegraph.GROUND_CIRCLE
	leap.telegraph_lead = 0.8
	leap.tracking_deg = 220.0
	leap.move_type = EnemyAttackData.MoveType.LEAP
	leap.shockwave_radius = 8.0
	leap.hitbox_size = Vector3(5.0, 2.0, 5.0)
	leap.hitbox_forward = 0.0
	leap.hitbox_height = 1.0
	_save(leap, "attacks/ammit_leap.tres")

	var roar := _eatk("ammit_roar", "roar", 0.4, 1.4, 0.4, 0.0, 7.0, 0.0, 60.0)
	roar.weight = 0.0
	roar.angle_max = 360.0
	roar.cooldown = 999.0
	roar.telegraph = EnemyAttackData.Telegraph.ROAR
	roar.move_type = EnemyAttackData.MoveType.ROAR
	roar.phase_min = 2
	roar.shake = 0.7
	_save(roar, "attacks/ammit_roar.tres")

	var summon := _eatk("ammit_summon", "summon", 1.0, 0.3, 0.8, 0.0, 0.0, 0.0, 40.0)
	summon.angle_max = 360.0
	summon.cooldown = 14.0
	summon.weight = 1.0
	summon.phase_min = 2
	summon.telegraph = EnemyAttackData.Telegraph.ROAR
	summon.move_type = EnemyAttackData.MoveType.SUMMON
	summon.spawn_count = 4
	summon.shake = 0.3
	_save(summon, "attacks/ammit_summon.tres")

	var burrow := _eatk("ammit_burrow", "burrow", 0.8, 2.2, 1.3, 36.0, 12.0, 4.0, 40.0)
	burrow.hitstop = 0.1
	burrow.shake = 0.8
	burrow.angle_max = 360.0
	burrow.cooldown = 11.0
	burrow.weight = 1.5
	burrow.phase_min = 2
	burrow.telegraph = EnemyAttackData.Telegraph.GROUND_CIRCLE
	burrow.telegraph_lead = 1.0
	burrow.move_type = EnemyAttackData.MoveType.BURROW
	burrow.move_speed = 7.0
	burrow.shockwave_radius = 3.2
	burrow.hitbox_size = Vector3(6.4, 2.5, 6.4)
	burrow.hitbox_forward = 0.0
	burrow.hitbox_height = 1.0
	_save(burrow, "attacks/ammit_burrow.tres")

	var ammit := EnemyData.new()
	ammit.display_name = "Ammit, Devourer of Hearts"
	ammit.max_hp = 900.0
	ammit.max_poise = 240.0
	ammit.poise_regen_delay = 4.0
	ammit.poise_regen_rate = 25.0
	ammit.stagger_duration = 3.0
	ammit.stagger_damage_mult = 1.5
	ammit.flinch_duration = 0.0
	ammit.knockback_resist = 0.95
	ammit.hyper_armor = true
	ammit.ka_reward = 2500
	ammit.walk_speed = 2.6
	ammit.run_speed = 5.5
	ammit.acceleration = 12.0
	ammit.turn_speed_deg = 150.0
	ammit.detect_radius = 40.0
	ammit.lose_radius = 90.0
	ammit.leash_radius = 90.0
	ammit.alert_time = 0.2
	ammit.strafe_radius = 6.5
	ammit.strafe_speed = 2.2
	ammit.uses_tokens = false
	ammit.think_interval = 0.2
	ammit.attacks.assign([load(R + "attacks/ammit_charge.tres"), load(R + "attacks/ammit_snap_1.tres"),
		load(R + "attacks/ammit_tail.tres"), load(R + "attacks/ammit_leap.tres"),
		load(R + "attacks/ammit_summon.tres"), load(R + "attacks/ammit_burrow.tres")])
	_save(ammit, "enemies/ammit.tres")


func _map(states: Array, looping: Array, xfade: float, fallbacks: Dictionary = {}) -> AnimationMap:
	var m := AnimationMap.new()
	m.states.assign(states)
	m.looping.assign(looping)
	m.xfade = xfade
	m.fallbacks = fallbacks
	return m


func _anim_maps() -> void:
	_save(_map([&"light_1", &"light_2", &"light_3", &"heavy_windup", &"heavy_charge", &"heavy_release",
		&"dodge", &"hit", &"hit_heavy", &"death", &"heal", &"cast", &"rest", &"grabbed", &"interact"],
		[&"idle", &"walk", &"run", &"heavy_charge", &"grabbed"], 0.05,
		{&"hit_heavy": &"hit", &"grabbed": &"hit_heavy", &"interact": &"cast", &"rest": &"heal"}), "animation/hero_anim_map.tres")
	_save(_map([&"alert", &"slam", &"grab", &"grab_hold", &"hit", &"stagger", &"death"],
		[&"idle", &"walk", &"run", &"grab_hold"], 0.1), "animation/mummy_anim_map.tres")
	_save(_map([&"alert", &"bite", &"hit", &"stagger", &"death"],
		[&"idle", &"walk", &"run"], 0.06), "animation/scarab_anim_map.tres")
	_save(_map([&"alert", &"combo_1", &"combo_2", &"combo_3", &"lunge", &"evade", &"hit", &"stagger", &"death"],
		[&"idle", &"walk", &"run"], 0.07), "animation/jackal_anim_map.tres")
	_save(_map([&"alert", &"spit", &"swipe", &"hit", &"stagger", &"death"],
		[&"idle", &"walk", &"run"], 0.1), "animation/cobra_anim_map.tres")
	_save(_map([&"alert", &"charge_windup", &"charge", &"charge_end", &"crash", &"snap_1", &"snap_2", &"tail",
		&"leap", &"roar", &"summon", &"burrow", &"emerge", &"hit", &"stagger", &"death"],
		[&"idle", &"walk", &"run", &"charge"], 0.12), "animation/ammit_anim_map.tres")
