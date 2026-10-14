class_name Ammit
extends EnemyBase
## Ammit, Devourer of Hearts.
## Phase 1: turning charge (crashing into a wall or the scales stuns her), double jaw snap,
## sweeping tail strike, leap with a shockwave.
## Phase 2 (HP < 50 %): roar (pause + lighting change), quicksand, scarab summons,
## faster combos (snap-snap-tail, +15 % speed), burrow and strike from below.

const SCARAB := preload("res://scenes/enemies/scarab.tscn")
const ROAR_ATTACK := preload("res://resources/attacks/ammit_roar.tres")
const SHOCKWAVE := preload("res://scripts/combat/shockwave.gd")
const MAX_MINIONS := 6

var arena: Node3D
var _phase2_pending: bool = false
var _crashed: bool = false
var _pending_stagger: bool = false
var _leap_from: Vector3
var _leap_to: Vector3
var _leap_has_target: bool = false
var _burrow_target: Vector3
var _burrow_locked: bool = false
var _trail_t: float = 0.0
var _hidden: bool = false
var _base_mask: int = 0
var _base_layer: int = 0


func _combatant_ready() -> void:
	super._combatant_ready()
	add_to_group(&"boss")
	telegraph_color = Color(1.0, 0.45, 0.2)
	_base_mask = collision_mask
	_base_layer = collision_layer


## Called by the BossArena when the player enters the hall.
func awaken() -> void:
	aware = true
	fsm.transition_to(&"Alert")
	AudioManager.play_event(&"ammit_roar", global_position)
	CameraShake.add_trauma(0.5)


func _pre_update(dt: float, real_dt: float) -> void:
	super._pre_update(dt, real_dt)
	if phase == 1 and not is_dead and health.ratio() <= 0.5:
		_phase2_pending = true
	if _phase2_pending and (fsm.is_in(&"Strafe") or fsm.is_in(&"Chase")):
		_phase2_pending = false
		phase = 2
		fsm.transition_to(&"Attack", {"attack": ROAR_ATTACK})


func _post_update(_dt: float, _real_dt: float) -> void:
	if _pending_stagger:
		_pending_stagger = false
		fsm.transition_to(&"Stagger", {"duration": 2.2, "anim": &"crash"})


func should_give_up() -> bool:
	return not player_alive()


func attack_weight_modifier(a: EnemyAttackData, dist: float, ang: float) -> float:
	match a.move_type:
		EnemyAttackData.MoveType.SPIN:
			return 3.5 if ang > 100.0 else (0.6 if dist < 4.0 else 0.2)
		EnemyAttackData.MoveType.CHARGE:
			return 2.2 if dist > 9.0 else 0.4
		EnemyAttackData.MoveType.LEAP:
			return 1.6 if dist > 7.0 else 0.3
		EnemyAttackData.MoveType.SUMMON:
			return 1.5 if _minion_count() < 2 else 0.0
	return 1.0


func _footstep() -> void:
	if player_alive() and distance_to_player() < 14.0:
		CameraShake.add_trauma(0.06)
	Vfx.dust(global_position, 3, 1.2)
	AudioManager.play_event(&"footstep_stone", global_position, 6.0)


# --- telegraphs ---------------------------------------------------------------------

func telegraph(a: EnemyAttackData) -> void:
	super.telegraph(a)
	if a.move_type == EnemyAttackData.MoveType.LUNGE:
		AudioManager.play_event(&"ammit_snap", global_position + Vector3.UP * 2.0, -4.0)


func telegraph_special(a: EnemyAttackData) -> void:
	match a.move_type:
		EnemyAttackData.MoveType.LEAP:
			_leap_to = _arena_clamp(player.global_position + player.move_velocity * 0.4 if player_alive() else global_position)
			_leap_has_target = true
			Vfx.ground_telegraph(_leap_to, 3.0, a.telegraph_lead + a.active, Color(1.0, 0.35, 0.15))
			AudioManager.play_event(&"telegraph_heavy", global_position)
		EnemyAttackData.MoveType.BURROW:
			AudioManager.play_event(&"burrow", global_position)
		_:
			AudioManager.play_event(&"ammit_roar", global_position, -6.0)
			CameraShake.add_trauma(0.25)


# --- special moves --------------------------------------------------------------------

func attack_begin_active(a: EnemyAttackData) -> bool:
	match a.move_type:
		EnemyAttackData.MoveType.CHARGE:
			_crashed = false
			collision_mask = CombatTypes.LAYER_WORLD | CombatTypes.LAYER_GATE
			hitbox.activate(a, GameState.balance.enemy_damage_mult)
			AudioManager.play_event(&"ammit_roar", global_position, -4.0)
			return true
		EnemyAttackData.MoveType.LEAP:
			if not _leap_has_target:
				_leap_to = _arena_clamp(player.global_position if player_alive() else global_position)
			_leap_has_target = false
			_leap_from = global_position
			use_physics_move = false
			face_instant(_leap_to - global_position)
			Vfx.dust(global_position, 14, 2.0)
			return true
		EnemyAttackData.MoveType.BURROW:
			_burrow_locked = false
			_trail_t = 0.0
			_go_under()
			return true
		EnemyAttackData.MoveType.SUMMON:
			_summon(a)
			return true
		EnemyAttackData.MoveType.ROAR:
			_roar()
			return true
	return false


func attack_update_active(a: EnemyAttackData, t: float, dt: float) -> bool:
	match a.move_type:
		EnemyAttackData.MoveType.CHARGE:
			return _update_charge(a, t, dt)
		EnemyAttackData.MoveType.LEAP:
			return _update_leap(a, t)
		EnemyAttackData.MoveType.BURROW:
			return _update_burrow(a, t, dt)
		EnemyAttackData.MoveType.SUMMON, EnemyAttackData.MoveType.ROAR:
			stop(dt)
			return t < a.active
	return false


func attack_end(_a: EnemyAttackData) -> void:
	collision_mask = _base_mask
	use_physics_move = true
	if _hidden and not is_dead:
		_surface()


func _update_charge(a: EnemyAttackData, t: float, dt: float) -> bool:
	if _crashed:
		return false
	if player_alive():
		face_toward(direction_to_node(player), a.charge_turn_deg, dt)
	move_velocity = forward() * a.move_speed
	_trail_t -= dt
	if _trail_t <= 0.0:
		_trail_t = 0.12
		Vfx.dust(global_position - forward() * 1.5, 3, 1.3)
	if t > 0.25:
		for i in get_slide_collision_count():
			var c := get_slide_collision(i)
			if c.get_collider() is StaticBody3D and absf(c.get_normal().y) < 0.5 and c.get_normal().dot(forward()) < -0.4:
				_crash()
				return false
	return t < a.active


func _crash() -> void:
	_crashed = true
	hitbox.deactivate()
	move_velocity = Vector3.ZERO
	knockback_velocity = -forward() * 4.0
	CameraShake.add_trauma(0.7)
	AudioManager.play_event(&"hit_stone", global_position + Vector3.UP * 1.5, 4.0)
	AudioManager.play_event(&"shockwave", global_position)
	Vfx.sand_burst(global_position + forward() * 2.5 + Vector3.UP * 1.5, -forward(), 30)
	Vfx.glint(global_position + Vector3.UP * 3.0, Color(1.0, 0.95, 0.7), 2.0, 0.5)
	_pending_stagger = true


func _update_leap(a: EnemyAttackData, t: float) -> bool:
	var u := clampf(t / maxf(a.active, 0.05), 0.0, 1.0)
	var p := _leap_from.lerp(_leap_to, u)
	p.y = lerpf(_leap_from.y, _leap_to.y, u) + 4.5 * 4.0 * u * (1.0 - u)
	global_position = p
	if u >= 1.0:
		_land(a)
		return false
	return true


func _land(a: EnemyAttackData) -> void:
	use_physics_move = true
	global_position = _leap_to
	vertical_velocity = 0.0
	hitbox.set_sphere(2.8, Vector3(0, 1.0, 0))
	hitbox.activate(a, GameState.balance.enemy_damage_mult, false)
	_spawn_shockwave(a, a.shockwave_radius, 0.55)
	CameraShake.add_trauma(0.8)
	_screen_punch(0.012)
	AudioManager.play_event(&"shockwave", global_position)
	Vfx.dust(global_position, 20, 2.5)


func _go_under() -> void:
	_hidden = true
	hurtbox.monitorable = false
	collision_layer = 0
	collision_mask = CombatTypes.LAYER_WORLD
	Vfx.sand_burst(global_position + Vector3.UP * 0.5, Vector3.UP, 30)
	AudioManager.play_event(&"burrow", global_position)
	CameraShake.add_trauma(0.35)


func _surface() -> void:
	_hidden = false
	hurtbox.monitorable = true
	collision_layer = _base_layer
	collision_mask = _base_mask


func _update_burrow(a: EnemyAttackData, t: float, dt: float) -> bool:
	var remaining := a.active - t
	if not _burrow_locked:
		if player_alive():
			var to := player.global_position - global_position
			to.y = 0.0
			move_velocity = to.normalized() * a.move_speed if to.length() > 1.0 else Vector3.ZERO
		if remaining <= a.telegraph_lead:
			_burrow_locked = true
			_burrow_target = _arena_clamp(player.global_position if player_alive() else global_position)
			Vfx.ground_telegraph(_burrow_target, a.shockwave_radius, remaining, Color(1.0, 0.3, 0.1))
			AudioManager.play_event(&"telegraph_heavy", _burrow_target)
	else:
		var to2 := _burrow_target - global_position
		to2.y = 0.0
		move_velocity = to2 / maxf(remaining, 0.1) if to2.length() > 0.2 else Vector3.ZERO
	_trail_t -= dt
	if _trail_t <= 0.0:
		_trail_t = 0.1
		Vfx.sand_burst(global_position + Vector3.UP * 0.2, Vector3.UP, 6)
		Vfx.dust(global_position, 3, 1.4)
	if t >= a.active:
		_erupt(a)
		return false
	return true


func _erupt(a: EnemyAttackData) -> void:
	global_position = Vector3(_burrow_target.x, global_position.y, _burrow_target.z)
	move_velocity = Vector3.ZERO
	_surface()
	if player_alive():
		face_instant(direction_to_node(player))
	hitbox.set_sphere(a.shockwave_radius, Vector3(0, 1.0, 0))
	hitbox.activate(a, GameState.balance.enemy_damage_mult, false)
	_spawn_shockwave(a, a.shockwave_radius + 3.0, 0.4)
	CameraShake.add_trauma(0.85)
	_screen_punch(0.014)
	AudioManager.play_event(&"erupt", global_position)
	Vfx.sand_burst(global_position + Vector3.UP, Vector3.UP, 40)
	Vfx.dust(global_position, 24, 3.0)


func _spawn_shockwave(a: EnemyAttackData, radius: float, duration: float) -> void:
	var sw: Shockwave = SHOCKWAVE.new()
	sw.setup(a, self, radius, duration)
	get_tree().current_scene.add_child(sw)
	sw.global_position = Vector3(global_position.x, global_position.y + 0.05, global_position.z)


func _summon(a: EnemyAttackData) -> void:
	var lv := get_tree().get_first_node_in_group(&"level") as Level
	var parent: Node = lv.enemies_root if lv != null else get_parent()
	var n := mini(a.spawn_count, MAX_MINIONS - _minion_count())
	AudioManager.play_event(&"ammit_roar", global_position)
	CameraShake.add_trauma(0.4)
	for i in n:
		var ang := TAU * float(i) / float(maxi(n, 1)) + randf() * 0.5
		var center := player.global_position if player_alive() else global_position
		var p := _arena_clamp(center + Vector3(cos(ang), 0, sin(ang)) * randf_range(4.0, 6.0))
		var s := SCARAB.instantiate() as EnemyBase
		s.position = p + Vector3.UP * 0.1
		parent.add_child(s)
		s.set_home(p, 0.0)
		s.add_to_group(&"ammit_minions")
		s.reset_physics_interpolation()
		s.become_aware()
		Vfx.sand_burst(p + Vector3.UP * 0.3, Vector3.UP, 16)


func _minion_count() -> int:
	var n := 0
	for m in get_tree().get_nodes_in_group(&"ammit_minions"):
		if is_instance_valid(m) and not bool(m.get("is_dead")):
			n += 1
	return n


func _roar() -> void:
	anim_speed = 1.15
	AudioManager.play_event(&"ammit_roar", global_position, 3.0)
	CameraShake.add_trauma(0.9)
	_screen_punch(0.016)
	Vfx.ring(global_position, 1.0, 14.0, 1.0, Color(1.0, 0.3, 0.2), 0.08)
	if player_alive() and distance_to_player() < 9.0:
		player.apply_knockback(direction_to_node(player), 7.0)
	if arena != null:
		arena.call(&"enter_phase_two")


func _screen_punch(amount: float) -> void:
	var lv := get_tree().get_first_node_in_group(&"level") as Level
	if lv != null and lv.screen_fx != null:
		lv.screen_fx.punch(amount)


func _arena_clamp(p: Vector3) -> Vector3:
	if arena != null:
		return arena.call(&"clamp_inside", p)
	return p


func _on_death(hit: HitInfo) -> void:
	super._on_death(hit)
	if arena != null:
		arena.call(&"on_boss_defeated", self)


func get_debug_state() -> String:
	return "AMMIT phase %d: %s  hp %d/%d  poise %d" % [phase, fsm.current_name(), int(health.current), int(health.max_health), int(poise.current)]
