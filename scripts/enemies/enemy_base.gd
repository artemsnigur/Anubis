class_name EnemyBase
extends Combatant
## Shared enemy logic: perception, navigation, attack selection with attack tokens,
## telegraphs, poise / stagger, Ka drop. Behaviour lives in the shared states
## (Idle/Patrol -> Alert -> Chase -> Strafe -> Attack -> Flinch/Stagger -> Dead);
## subclasses add special moves through the hooks at the bottom.

signal defeated(enemy: EnemyBase)

@export var data: EnemyData
## Optional patrol points (world positions). Empty = guard the spawn point.
@export var patrol_points: Array[Vector3] = []
@export var hit_sound: StringName = &"hit_enemy"
@export var voice_sound: StringName = &""
## Material burst on hit: "sand" or "sparks".
@export var hit_burst: StringName = &"sand"

@onready var nav: NavigationAgent3D = $NavAgent

var player: Player
var home_position: Vector3 = Vector3.ZERO
var home_yaw: float = 0.0
var cooldowns: Dictionary = {}
var phase: int = 1
var aware: bool = false
var evade_cooldown: float = 0.0
var strafe_dir: float = 1.0
var _director: AIDirector
var _repath_t: float = 0.0
var _last_nav_target: Vector3 = Vector3(INF, INF, INF)


func _combatant_ready() -> void:
	add_to_group(&"enemies")
	faction = CombatTypes.Faction.ENEMY
	hurtbox.faction = faction
	hitbox.faction = faction
	if data != null:
		health.setup(data.max_hp, true)
		poise.setup(data.max_poise, data.poise_regen_delay, data.poise_regen_rate)
		knockback_resist = data.knockback_resist
	poise.broken.connect(_on_poise_broken)
	home_position = global_position
	home_yaw = rotation.y
	strafe_dir = 1.0 if randf() < 0.5 else -1.0
	nav.path_desired_distance = 0.6
	nav.target_desired_distance = 0.5
	nav.radius = body_radius
	nav.avoidance_enabled = false


## Called after the enemy is placed in the world (spawner) to set its home.
func set_home(pos: Vector3, yaw: float) -> void:
	home_position = pos
	home_yaw = yaw


func get_clip_table() -> Dictionary:
	var t := {}
	if data == null:
		return t
	for a: EnemyAttackData in all_attacks():
		t[a.anim] = {"windup": a.windup, "active": a.active, "recovery": a.recovery, "lead": a.telegraph_lead}
	t[&"hit"] = {"length": maxf(data.flinch_duration, 0.2)}
	t[&"stagger"] = {"length": data.stagger_duration}
	return t


## Attack list including combo follow-ups (for clip generation).
func all_attacks() -> Array[EnemyAttackData]:
	var out: Array[EnemyAttackData] = []
	var stack: Array[EnemyAttackData] = []
	stack.append_array(data.attacks)
	while not stack.is_empty():
		var a: EnemyAttackData = stack.pop_back()
		if a == null or out.has(a):
			continue
		out.append(a)
		if a.combo_next != null:
			stack.append(a.combo_next)
		if a.combo_next_phase2 != null:
			stack.append(a.combo_next_phase2)
	return out


func _pre_update(dt: float, _real_dt: float) -> void:
	for k: Variant in cooldowns.keys():
		cooldowns[k] = float(cooldowns[k]) - dt
		if float(cooldowns[k]) <= 0.0:
			cooldowns.erase(k)
	if evade_cooldown > 0.0:
		evade_cooldown -= dt
	if player == null or not is_instance_valid(player):
		player = get_tree().get_first_node_in_group(&"player") as Player


# --- perception -------------------------------------------------------------------

func player_alive() -> bool:
	return player != null and is_instance_valid(player) and not player.is_dead


func distance_to_player() -> float:
	if not player_alive():
		return INF
	return flat_distance_to(player.global_position)


func angle_to_player_deg() -> float:
	if not player_alive():
		return 180.0
	var to := player.global_position - global_position
	to.y = 0.0
	if to.length_squared() < 0.0001:
		return 0.0
	return rad_to_deg(absf(forward().signed_angle_to(to.normalized(), Vector3.UP)))


func can_see_player() -> bool:
	if not player_alive():
		return false
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 1.2, player.global_position + Vector3.UP * 1.0, CombatTypes.LAYER_WORLD | CombatTypes.LAYER_GATE)
	return space.intersect_ray(q).is_empty()


func should_detect_player() -> bool:
	if not player_alive():
		return false
	var d := distance_to_player()
	if d > data.detect_radius:
		return false
	if absf(player.global_position.y - global_position.y) > 3.0:
		return false
	return can_see_player()


func should_give_up() -> bool:
	if not player_alive():
		return true
	if distance_to_player() > data.lose_radius:
		return true
	return flat_distance_to(home_position) > data.leash_radius


## Wakes up nearby allies (pack behaviour).
func alert_allies(radius: float = 9.0) -> void:
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var e := n as EnemyBase
		if e == null or e == self or e.is_dead or e.aware:
			continue
		if e.global_position.distance_to(global_position) <= radius:
			e.become_aware()


func become_aware() -> void:
	if aware or is_dead:
		return
	aware = true
	if fsm.is_in(&"Idle"):
		fsm.transition_to(&"Alert")


## State to go back to after a flinch / stagger.
func recover_state() -> StringName:
	return &"Strafe" if player_alive() else &"Return"


func player_is_attacking() -> bool:
	return player_alive() and (player.fsm.is_in(&"Attack") or player.fsm.is_in(&"Heavy"))


# --- movement ---------------------------------------------------------------------

## Steers along the navmesh toward `pos`. Returns the remaining flat distance.
func nav_move_to(pos: Vector3, speed: float, dt: float, face_move: bool = true) -> float:
	_repath_t -= dt
	if _repath_t <= 0.0 or _last_nav_target.distance_to(pos) > 1.0:
		nav.target_position = pos
		_last_nav_target = pos
		_repath_t = 0.25
	var next := nav.get_next_path_position()
	var dir := next - global_position
	dir.y = 0.0
	if dir.length() < 0.05 or nav.is_navigation_finished():
		dir = pos - global_position
		dir.y = 0.0
	var dist := flat_distance_to(pos)
	if dir.length_squared() > 0.0001:
		dir = dir.normalized()
	steer(dir, speed, dt)
	if face_move and dir.length_squared() > 0.0001:
		face_toward(dir, data.turn_speed_deg, dt)
	return dist


## Accelerates toward dir * speed, adding separation from other enemies.
func steer(dir: Vector3, speed: float, dt: float) -> void:
	var desired := dir * speed + separation() * speed * 0.8
	move_velocity = move_velocity.move_toward(desired, data.acceleration * dt)


func stop(dt: float, decel: float = -1.0) -> void:
	move_velocity = move_velocity.move_toward(Vector3.ZERO, (data.acceleration if decel < 0.0 else decel) * dt)


func separation() -> Vector3:
	var push := Vector3.ZERO
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var e := n as EnemyBase
		if e == null or e == self or e.is_dead:
			continue
		var d := global_position - e.global_position
		d.y = 0.0
		var r := body_radius + e.body_radius + 0.6
		var l := d.length()
		if l < r and l > 0.001:
			push += d / l * (1.0 - l / r)
	return push.limit_length(1.0)


func face_player(dt: float, rate_deg: float = -1.0) -> void:
	if player_alive():
		face_toward(direction_to_node(player), data.turn_speed_deg if rate_deg < 0.0 else rate_deg, dt)


# --- attacks / tokens ----------------------------------------------------------------

func director() -> AIDirector:
	if _director == null or not is_instance_valid(_director):
		_director = AIDirector.get_instance(get_tree())
	return _director


func request_token() -> bool:
	if not data.uses_tokens:
		return true
	return director().request(self)


func release_token() -> void:
	if data.uses_tokens and _director != null and is_instance_valid(_director):
		_director.release(self)


func attack_available(a: EnemyAttackData) -> bool:
	if a.weight <= 0.0 or a.phase_min > phase:
		return false
	if a.phase_one_only and phase > 1:
		return false
	return not cooldowns.has(a.id)


## Weighted random choice among attacks usable from the current distance/angle.
## With `ignore_range` it returns the attack we would like to use next (to approach).
func choose_attack(ignore_range: bool = false) -> EnemyAttackData:
	var dist := distance_to_player()
	var ang := angle_to_player_deg()
	var pool: Array[EnemyAttackData] = []
	var total := 0.0
	for a: EnemyAttackData in data.attacks:
		if not attack_available(a):
			continue
		if not ignore_range:
			if dist < a.range_min or dist > a.range_max + body_radius:
				continue
			if ang > a.angle_max * 0.5 and a.angle_max < 360.0:
				continue
		var w := a.weight * attack_weight_modifier(a, dist, ang)
		if w <= 0.0:
			continue
		pool.append(a)
		total += w
	if pool.is_empty():
		return null
	var r := randf() * total
	for a in pool:
		r -= a.weight * attack_weight_modifier(a, dist, ang)
		if r <= 0.0:
			return a
	return pool[pool.size() - 1]


## Subclass hook to bias attack choice (e.g. tail sweep when the player is behind).
func attack_weight_modifier(_a: EnemyAttackData, _dist: float, _ang: float) -> float:
	return 1.0


func start_cooldown(a: EnemyAttackData) -> void:
	cooldowns[a.id] = a.cooldown


## Next attack of a combo for the current phase.
func combo_follow_up(a: EnemyAttackData) -> EnemyAttackData:
	if phase >= 2 and a.combo_next_phase2 != null:
		return a.combo_next_phase2
	return a.combo_next


# --- telegraphs ---------------------------------------------------------------------

func telegraph(a: EnemyAttackData) -> void:
	var socket := rig.get_socket(&"weapon_tip") if rig.has_socket(&"weapon_tip") else rig.get_socket(&"head")
	var p := socket.global_position
	match a.telegraph:
		EnemyAttackData.Telegraph.GLINT:
			Vfx.glint(p, Color(1.0, 0.85, 0.45), 1.3, 0.3)
			flash_fx.flash(Color(1.0, 0.75, 0.3), 0.25, 0.35)
			AudioManager.play_event(&"telegraph", p)
		EnemyAttackData.Telegraph.FLASH:
			Vfx.glint(p, Color(1.0, 0.25, 0.15), 1.7, 0.35)
			flash_fx.flash(Color(1.0, 0.2, 0.1), 0.35, 0.8)
			AudioManager.play_event(&"telegraph_heavy", p)
		_:
			telegraph_special(a)


# --- hit reactions --------------------------------------------------------------------

func _modify_incoming_damage(hit: HitInfo) -> float:
	if fsm.is_in(&"Stagger"):
		return hit.damage * data.stagger_damage_mult
	return hit.damage


func _on_hit_received(hit: HitInfo) -> void:
	if is_dead:
		return
	super._on_hit_received(hit)
	var p := hit.position
	if hit_burst == &"sparks":
		Vfx.hit_sparks(p, hit.direction, hit.is_heavy)
	else:
		Vfx.hit_sparks(p, hit.direction, hit.is_heavy)
		Vfx.sand_burst(p, hit.direction, 18 if hit.is_heavy else 10)
	AudioManager.play_event(&"hit_heavy" if hit.is_heavy else hit_sound, p)


func _react_to_hit(hit: HitInfo) -> void:
	if not aware:
		become_aware()
		alert_allies()
	if hit.is_dot:
		return
	if poise.apply(hit.poise_damage):
		return
	if fsm.current != null and not fsm.current.can_be_interrupted():
		return
	if fsm.is_in(&"Attack") and data.hyper_armor:
		return
	if fsm.is_in(&"Stagger"):
		return
	if data.flinch_duration > 0.0:
		fsm.transition_to(&"Flinch")


func _on_poise_broken() -> void:
	if is_dead:
		return
	release_token()
	hitbox.deactivate()
	AudioManager.play_event(&"stagger", global_position + Vector3.UP)
	Vfx.glint(global_position + Vector3.UP * (lock_height + 0.4), Color(1.0, 0.95, 0.7), 2.0, 0.45)
	CameraShake.add_trauma(0.25)
	fsm.transition_to(&"Stagger")


func _on_death(_hit: HitInfo) -> void:
	release_token()
	hitbox.deactivate()
	GameState.add_ka(data.ka_reward if data != null else 0)
	if player_alive():
		Vfx.ka_orbs(global_position + Vector3.UP, player, clampi(data.ka_reward / 8, 3, 14))
		AudioManager.play_event(&"ka_pickup", player.global_position)
	AudioManager.play_event(&"enemy_death", global_position)
	fsm.transition_to(&"Dead")
	defeated.emit(self)


func _footstep() -> void:
	if move_velocity.length() > 3.0 and randf() < 0.5:
		Vfx.dust(global_position, 2, 0.6)


# --- subclass hooks for special moves -------------------------------------------------

## Called when an attack's active phase begins. Return true if handled specially
## (the generic hitbox activation is then skipped).
func attack_begin_active(_a: EnemyAttackData) -> bool:
	return false


## Called every frame of the active phase for special moves.
## Return true while the special move is still running (extends the active phase).
func attack_update_active(_a: EnemyAttackData, _t: float, _dt: float) -> bool:
	return false


func attack_end(_a: EnemyAttackData) -> void:
	return


func telegraph_special(_a: EnemyAttackData) -> void:
	return


func grab_socket() -> Node3D:
	return rig.get_socket(&"grab")


func get_debug_state() -> String:
	var tok := ""
	if _director != null and is_instance_valid(_director) and _director.has_token(self):
		tok = " [TOKEN]"
	return "%s: %s  hp %d  poise %d%s" % [name, fsm.current_name(), int(health.current), int(poise.current), tok]
