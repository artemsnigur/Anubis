class_name BossArena
extends Node3D
## The Hall of Two Truths: giant scales of Ma'at in the centre, the dormant Ammit,
## quicksand pools that open in phase 2. Starts the fight when the player walks in
## (sand veil closes, boss bar, camera zoom-out), handles reset on death and victory.

const AMMIT_SCENE := preload("res://scenes/enemies/ammit.tscn")
const QUICKSAND_SHADER := preload("res://assets/shaders/quicksand.gdshader")
const HALF := 18.0
const BOSS_NAME := "Ammit, Devourer of Hearts"
const QUICKSAND_RADIUS := 3.2

var boss: Ammit
var fight_active: bool = false
var phase_two: bool = false
var _level: Level
var _beam: Node3D
var _pools: Array[MeshInstance3D] = []
var _pool_centers: Array[Vector3] = []
var _dot_t: float = 0.0
var _dot_attack := AttackData.new()
var _t: float = 0.0


func _ready() -> void:
	_level = get_parent() as Level
	_dot_attack.id = &"quicksand"
	_dot_attack.damage = 3.0
	_dot_attack.knockback = 0.0
	_dot_attack.hitstop = 0.0
	_dot_attack.shake = 0.0
	_build_scales()
	_build_pools()


func _build_scales() -> void:
	var root: Node3D = self
	if _level != null:
		root = _level.nav_region
	var body := StaticBody3D.new()
	body.collision_layer = CombatTypes.LAYER_WORLD
	root.add_child(body)
	body.global_position = global_position
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.6, 1.4, 3.6)
	cs.shape = bs
	cs.position = Vector3(0, 0.7, 0)
	body.add_child(cs)
	var pillar := CollisionShape3D.new()
	var ps := CylinderShape3D.new()
	ps.radius = 0.6
	ps.height = 6.5
	pillar.shape = ps
	pillar.position = Vector3(0, 3.25, 0)
	body.add_child(pillar)
	Kit.mesh(body, PlaceholderRig.box(Vector3(4.2, 0.4, 4.2)), Mats.get_mat(&"basalt_glyph"), Vector3(0, 0.2, 0))
	Kit.mesh(body, PlaceholderRig.box(Vector3(3.6, 1.0, 3.6)), Mats.get_mat(&"basalt_glyph"), Vector3(0, 0.9, 0))
	Kit.mesh(body, PlaceholderRig.box(Vector3(3.8, 0.12, 3.8)), Mats.get_mat(&"gold_world"), Vector3(0, 1.45, 0))
	Kit.mesh(body, PlaceholderRig.cylinder(0.32, 0.45, 6.0, 12), Mats.get_mat(&"gold_world"), Vector3(0, 4.4, 0))
	Kit.mesh(body, PlaceholderRig.sphere(0.45), Mats.get_mat(&"gold_world"), Vector3(0, 7.5, 0))
	# The beam sways slowly: the heart is heavier than it should be...
	_beam = Node3D.new()
	_beam.position = Vector3(0, 7.2, 0)
	body.add_child(_beam)
	Kit.mesh(_beam, PlaceholderRig.box(Vector3(9.0, 0.3, 0.35)), Mats.get_mat(&"gold_world"), Vector3.ZERO)
	for side: float in [-1.0, 1.0]:
		var hang := Node3D.new()
		hang.position = Vector3(4.3 * side, 0, 0)
		_beam.add_child(hang)
		for c: float in [-0.6, 0.6]:
			Kit.mesh(hang, PlaceholderRig.cylinder(0.025, 0.025, 2.8, 4), Mats.get_mat(&"gold"), Vector3(c, -1.4, 0), Vector3(0, 0, c * 10.0 * side))
		Kit.mesh(hang, PlaceholderRig.cylinder(1.25, 1.0, 0.18, 18), Mats.get_mat(&"gold_world"), Vector3(0, -2.85, 0))
		if side < 0.0:
			var heart_mat := Mats.get_mat(&"heart_glow")
			Kit.mesh(hang, PlaceholderRig.sphere(0.32), heart_mat, Vector3(0.18, -2.45, 0))
			Kit.mesh(hang, PlaceholderRig.sphere(0.32), heart_mat, Vector3(-0.18, -2.45, 0))
			Kit.mesh(hang, PlaceholderRig.cylinder(0.46, 0.0, 0.6, 12), heart_mat, Vector3(0, -2.75, 0))
			var hl := OmniLight3D.new()
			hl.light_color = Color(1.0, 0.25, 0.2)
			hl.light_energy = 2.5
			hl.omni_range = 6.0
			hl.position = Vector3(0, -2.2, 0)
			hang.add_child(hl)
		else:
			Kit.mesh(hang, PlaceholderRig.sphere(0.3, 1.6, 10), Mats.get_mat(&"feather"), Vector3(0, -2.0, 0), Vector3(0, 0, 18), Vector3(0.6, 1.0, 0.15))
			Kit.mesh(hang, PlaceholderRig.cylinder(0.02, 0.02, 1.7, 4), Mats.get_mat(&"gold"), Vector3(0.1, -2.0, 0), Vector3(0, 0, 18))
	var tw := create_tween().set_loops()
	tw.tween_property(_beam, "rotation_degrees:z", 6.0, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(_beam, "rotation_degrees:z", 2.0, 3.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _build_pools() -> void:
	for p: Vector3 in [Vector3(-9, 0, -8), Vector3(9, 0, -8), Vector3(-9, 0, 8), Vector3(9, 0, 8)]:
		var mi := MeshInstance3D.new()
		var pm := PlaneMesh.new()
		pm.size = Vector2(QUICKSAND_RADIUS * 2.0, QUICKSAND_RADIUS * 2.0)
		mi.mesh = pm
		var mat := ShaderMaterial.new()
		mat.shader = QUICKSAND_SHADER
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = p + Vector3(0, 0.03, 0)
		mi.scale = Vector3(0.01, 1.0, 0.01)
		mi.visible = false
		add_child(mi)
		_pools.append(mi)
		_pool_centers.append(p)


## Called by the level before navigation baking (and after loading a save).
func apply_state() -> void:
	if not GameState.get_flag(&"boss_defeated"):
		_spawn_boss()


func _spawn_boss() -> void:
	if boss != null and is_instance_valid(boss):
		boss.queue_free()
	boss = AMMIT_SCENE.instantiate() as Ammit
	boss.arena = self
	boss.position = global_position + Vector3(0, 0.1, -10.5)
	boss.rotation.y = PI
	var parent: Node = _level.enemies_root if _level != null else get_parent()
	parent.add_child(boss)
	boss.set_home(boss.global_position, PI)


func clamp_inside(p: Vector3) -> Vector3:
	var m := 2.5
	var c := global_position
	return Vector3(clampf(p.x, c.x - HALF + m, c.x + HALF - m), c.y, clampf(p.z, c.z - HALF + m, c.z + HALF - m))


func _player_inside(margin: float) -> bool:
	var pl := _level.player if _level != null else null
	if pl == null or pl.is_dead:
		return false
	var d := pl.global_position - global_position
	return absf(d.x) < HALF - margin and absf(d.z) < HALF - margin and absf(d.y) < 3.0


func _physics_process(delta: float) -> void:
	_t += delta
	if _level == null:
		return
	if not fight_active and boss != null and is_instance_valid(boss) and not boss.is_dead and _player_inside(2.5):
		start_fight()
	if phase_two:
		_quicksand(delta)


func start_fight() -> void:
	fight_active = true
	var veil: SandVeil = _level.get("veil")
	if veil != null:
		veil.raise_veil()
	boss.awaken()
	_level.hud.show_boss(boss, BOSS_NAME)
	_level.camera.zoom = 1.35
	AudioManager.play_music("music_boss", 1.0)


func enter_phase_two() -> void:
	phase_two = true
	_level.atmosphere.apply_preset(&"hall_rage", false, 1.2)
	_level.hud.notify("The Devourer hungers - the floor turns to quicksand", Color(1.0, 0.45, 0.3))
	for mi in _pools:
		mi.visible = true
		var tw := mi.create_tween()
		tw.tween_property(mi, "scale", Vector3.ONE, 1.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		Vfx.sand_burst(mi.global_position + Vector3.UP * 0.3, Vector3.UP, 26)
	AudioManager.play_event(&"burrow", global_position, 2.0)


func _quicksand(delta: float) -> void:
	var pl := _level.player
	if pl == null or pl.is_dead:
		return
	var inside := false
	for c in _pool_centers:
		var w := global_position + c
		if Vector2(pl.global_position.x - w.x, pl.global_position.z - w.z).length() < QUICKSAND_RADIUS * 0.9:
			inside = true
			break
	pl.speed_multiplier = 0.5 if inside else 1.0
	if inside:
		_dot_t -= delta
		if _dot_t <= 0.0:
			_dot_t = 0.5
			var h := HitInfo.from_attack(_dot_attack, null, CombatTypes.Faction.HAZARD)
			h.is_dot = true
			h.direction = Vector3.FORWARD
			h.position = pl.global_position
			pl.hurtbox.receive_hit(h)
			Vfx.dust(pl.global_position, 3, 0.8)


func on_boss_defeated(_b: Ammit) -> void:
	fight_active = false
	phase_two = false
	GameState.set_flag(&"boss_defeated", true)
	HitStop.slow_motion(0.25, 1.8)
	_level.fader.flash(Color(1.0, 0.95, 0.8), 1.4, 0.95)
	_level.screen_fx.punch(0.02)
	CameraShake.add_trauma(1.0)
	_level.hud.hide_boss()
	if _level.player != null:
		_level.player.speed_multiplier = 1.0
	for m in get_tree().get_nodes_in_group(&"ammit_minions"):
		if is_instance_valid(m) and not bool(m.get("is_dead")):
			var h := HitInfo.new()
			h.damage = 999.0
			h.direction = Vector3.UP
			(m as EnemyBase).hurtbox.receive_hit(h)
	AudioManager.play_event(&"ammit_roar", global_position, 4.0)
	AudioManager.stop_music(2.0)
	_victory_sequence.call_deferred()


func _victory_sequence() -> void:
	await get_tree().create_timer(1.8, true, false, true).timeout
	for mi in _pools:
		var tw := mi.create_tween()
		tw.tween_property(mi, "scale", Vector3(0.01, 1.0, 0.01), 1.5)
		tw.tween_callback(mi.hide)
	_level.atmosphere.apply_preset(&"hall", false, 2.5)
	_level.camera.zoom = 1.0
	var veil: SandVeil = _level.get("veil")
	if veil != null:
		veil.drop_veil()
	var exit_gate: Gate = _level.get("exit_gate")
	if exit_gate != null:
		exit_gate.open()
	_level.hud.show_banner("The Devourer is silenced", "The Feather of Ma'at is yours. The gate to the Field of Reeds opens.", 3.5)
	AudioManager.play_event(&"victory")
	Vfx.motes(global_position + Vector3.UP * 4.0, 60)
	SaveSystem.save_game()


## Player died or rested: put the hall back to its dormant state.
func reset_arena() -> void:
	fight_active = false
	phase_two = false
	for m in get_tree().get_nodes_in_group(&"ammit_minions"):
		m.queue_free()
	for mi in _pools:
		mi.visible = false
		mi.scale = Vector3(0.01, 1.0, 0.01)
	if _level != null:
		_level.camera.zoom = 1.0
		_level.hud.hide_boss()
		if _level.player != null:
			_level.player.speed_multiplier = 1.0
	if GameState.get_flag(&"boss_defeated"):
		if boss != null and is_instance_valid(boss):
			boss.queue_free()
		boss = null
	else:
		_spawn_boss()
