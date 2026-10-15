class_name Player
extends Combatant
## The awakened ushabti. Movement, resources (HP, stamina, solar energy, Ankh charges),
## action gating with input buffer + cancel windows, aim + soft aim assist, lock-on.

signal resources_changed
signal interact_target_changed(target: Node)
signal death_finished
## A foot landed (anim event): &"r" / &"l", or &"" when the clip does not say.
signal footstep_side(side: StringName)

const RA_PROJECTILE := preload("res://scenes/combat/projectile.tscn")

@onready var input: PlayerInput = $PlayerInput
@onready var lock_on: LockOn = $LockOn
@onready var trail: WeaponTrail = $WeaponTrail
@onready var interact_area: Area3D = $InteractArea

var stats: PlayerStats
var balance: BalanceConfig
## Procedural "alive" layers on the rig bones (breathing, look-at, secondary motion, dust).
var alive: HeroAlive
## Active feel preset (GameState.feel); re-applied when F7 / F6 change it.
var feel: FeelPreset
var stamina: float = 100.0
var max_stamina: float = 100.0
var energy: float = 0.0
var ankh: int = 3
var invulnerable_time: float = 0.0
var last_safe_position: Vector3 = Vector3.ZERO
var speed_multiplier: float = 1.0
var hazard_count: int = 0
var god_mode: bool = false
var interactable: Node = null
var game_camera: GameCamera
var _stamina_delay: float = 0.0
var _safe_timer: float = 0.0
var _step_toggle: bool = false
var _last_shake_frame: int = -1
var _pivoting: bool = false
var _move_input_prev: bool = false
var _smear_on: bool = false
var _released_enemies: Array[CollisionObject3D] = []
var _look_ahead_hold: Vector3 = Vector3.ZERO
var _look_ahead_idle: float = 0.0
var _last_step_msec: Dictionary = {}


func _combatant_ready() -> void:
	add_to_group(&"player")
	stats = GameState.player_stats
	balance = GameState.balance
	fsm.immediate_transitions = true
	animator.prime_transitions = true
	alive = HeroAlive.new()
	alive.setup(self)
	GameState.feel_changed.connect(_apply_feel)
	_apply_feel(GameState.feel)
	faction = CombatTypes.Faction.PLAYER
	hurtbox.faction = faction
	hitbox.faction = faction
	refresh_stats(true)
	trail.setup(rig.get_socket(&"trail_base"), rig.get_socket(&"trail_tip"))
	interact_area.area_entered.connect(_on_interact_area_changed.unbind(1))
	interact_area.area_exited.connect(_on_interact_area_changed.unbind(1))
	lock_on.player = self
	last_safe_position = global_position
	_find_camera.call_deferred()


func _apply_feel(f: FeelPreset) -> void:
	feel = f
	animator.set_xfades(f.combat_xfade, f.recover_xfade)
	motion.configure(f)


func _find_camera() -> void:
	game_camera = get_tree().get_first_node_in_group(&"game_camera") as GameCamera
	if game_camera != null:
		input.camera = game_camera.camera


## Re-reads max values from GameState (after level up / reward). `fill` restores everything.
func refresh_stats(fill: bool) -> void:
	var max_hp := GameState.max_hp()
	health.setup(max_hp, fill)
	max_stamina = stats.max_stamina
	if fill:
		stamina = max_stamina
		ankh = GameState.max_ankh()
	resources_changed.emit()


func get_clip_table() -> Dictionary:
	var s := GameState.player_stats
	var t := {}
	for a: AttackData in s.light_attacks:
		t[a.anim] = {"windup": a.windup, "active": a.active, "recovery": a.recovery}
	var h := s.heavy_attack
	t[&"heavy_windup"] = {"length": h.windup}
	t[&"heavy_release"] = {"windup": h.windup, "active": h.active, "recovery": h.recovery}
	var r := s.ranged_attack
	t[&"cast"] = {"windup": r.windup, "active": r.active, "recovery": r.recovery}
	t[&"dodge"] = {"length": GameState.feel.dodge_duration}
	t[&"heal"] = {"length": s.heal_duration, "apply": s.heal_apply_time}
	t[&"hit"] = {"length": s.hurt_duration}
	t[&"hit_heavy"] = {"length": s.heavy_hurt_duration}
	return t


## First thing in the tick: read input, so the state machine sees a press in the tick
## it arrives. A dodge press may cut the hero's own hitstop short when it can act on it.
func _early_update(real_dt: float) -> void:
	var frozen := hitstop_left > real_dt * 0.5
	var dodge := input.poll(0.0 if frozen else real_dt, real_dt)
	if dodge and frozen and feel.dodge_breaks_hitstop and fsm.current != null \
			and fsm.current.has_method(&"accepts") and bool(fsm.current.call(&"accepts", &"dodge")):
		hitstop_left = 0.0


func _pre_update(dt: float, real_dt: float) -> void:
	# Stamina regeneration.
	if _stamina_delay > 0.0:
		_stamina_delay -= dt
	elif stamina < max_stamina:
		stamina = minf(max_stamina, stamina + stats.stamina_regen * dt)
		resources_changed.emit()
	if invulnerable_time > 0.0:
		invulnerable_time -= real_dt
	hurtbox.invulnerable = invulnerable_time > 0.0 or _state_iframes()
	lock_on.update_lock(dt)
	# Remember the last safe ground position (used to drop the Ka heart).
	_safe_timer -= real_dt
	if _safe_timer <= 0.0 and is_on_floor() and hazard_count == 0 and not is_dead:
		_safe_timer = 0.25
		last_safe_position = global_position


func _post_update(dt: float, real_dt: float) -> void:
	# Again after the state machine: a dodge entered this tick is invulnerable this tick.
	hurtbox.invulnerable = invulnerable_time > 0.0 or _state_iframes()
	alive.update(dt, real_dt)


func teleport_to(pos: Vector3, yaw: float) -> void:
	super.teleport_to(pos, yaw)
	if alive != null:
		alive.reset()


func _state_iframes() -> bool:
	return fsm.current != null and fsm.current.has_method(&"has_iframes") and bool(fsm.current.call(&"has_iframes"))


func _process(_delta: float) -> void:
	RenderingServer.global_shader_parameter_set(&"player_position", get_global_transform_interpolated().origin)


# --- resources ------------------------------------------------------------------

func has_stamina() -> bool:
	return not stats.stamina_enabled or stamina > 0.0


func spend_stamina(cost: float) -> void:
	if not stats.stamina_enabled or cost <= 0.0:
		return
	stamina = maxf(stamina - cost, -15.0)
	_stamina_delay = stats.stamina_regen_delay
	resources_changed.emit()


func add_energy(charges: float) -> void:
	var before := int(floor(energy))
	energy = minf(float(stats.max_energy), energy + charges * GameState.spirit_energy_multiplier())
	if int(floor(energy)) > before:
		AudioManager.play_event(&"charge_ready", null, -8.0)
	resources_changed.emit()


func can_cast() -> bool:
	return energy >= 1.0


func melee_multiplier() -> float:
	return GameState.melee_multiplier()


func grant_iframes(duration: float) -> void:
	invulnerable_time = maxf(invulnerable_time, duration)


# --- movement helpers ---------------------------------------------------------------

## Run speed of the active preset.
func run_speed() -> float:
	return stats.run_speed * feel.run_speed_mult


## Camera-relative locomotion (FeelPreset "Movement"): separate acceleration,
## deceleration and reversal rates (exponential approach + linear floor, frame-rate
## independent), exponential turning, instant facing when starting from a standstill,
## and a fast pivot (with a skid) when the input reverses at speed.
func locomote(dir: Vector3, max_speed: float, dt: float, allow_face: bool = true) -> void:
	if dt <= 0.0:
		return
	if feel.heading_locomotion and allow_face and lock_on.target == null:
		_locomote_heading(dir, max_speed, dt)
		return
	var f := feel
	var target := dir * max_speed * speed_multiplier
	var v := move_velocity
	var speed := v.length()
	var sharp := f.accel_sharpness
	var linear := f.accel_linear
	var reversing := speed > 0.5 and target.length() > 0.1 \
		and v.dot(target) < cos(deg_to_rad(f.reverse_angle_deg)) * speed * target.length()
	if reversing:
		sharp = f.reverse_sharpness
		linear = f.reverse_linear
		if not _pivoting and speed > run_speed() * 0.55:
			_pivoting = true
			_on_pivot(v / speed, speed / run_speed())
	elif target.length() < speed - 0.001:
		sharp = f.decel_sharpness
		linear = f.decel_linear
	var has_input := dir.length() > 0.1
	if has_input and not _move_input_prev and speed < 0.5 and dir.length() > 0.8:
		alive.run_start(dir.normalized())
	elif not has_input and _move_input_prev and speed > run_speed() * 0.85:
		alive.skid(0.45, v / speed)
	_move_input_prev = has_input
	if sharp > 0.0:
		v = v.lerp(target, 1.0 - exp(-sharp * dt))
	move_velocity = v.move_toward(target, linear * dt)
	if allow_face:
		var t := lock_on.target
		if t != null and move_velocity.length() < run_speed() * 0.6:
			_turn_to(direction_to_node(t), f.turn_sharpness, dt)
		elif dir.length() > 0.1:
			if speed < f.snap_face_speed:
				face_instant(dir)
			else:
				_turn_to(dir, f.pivot_turn_sharpness if _pivoting else f.turn_sharpness, dt)
	if _pivoting and (dir.length() < 0.1 or absf(angle_difference(rotation.y, yaw_for(dir))) < deg_to_rad(12.0)):
		_pivoting = false
	animator.set_locomotion(move_velocity.length(), run_speed(), f.speed_matched_locomotion)


## Heading model (weight): the body turns toward the input at a capped, speed-dependent
## rate and moves where it faces, so it carves arcs instead of sliding sideways; speed
## builds and bleeds off at the preset's rates and drops while the body is misaligned.
## Reversing at speed brakes first (plant + skid), then pivots and pushes off again.
func _locomote_heading(dir: Vector3, max_speed: float, dt: float) -> void:
	var f := feel
	var run := run_speed()
	var speed := move_velocity.length()
	var has_input := dir.length() > 0.1
	var target_speed := 0.0
	var braking := false
	if has_input:
		var want := dir.normalized()
		var diff := angle_difference(rotation.y, yaw_for(want))
		if absf(diff) > deg_to_rad(f.brake_turn_angle_deg) and speed > run * f.brake_speed_frac:
			braking = true
			if not _pivoting:
				_pivoting = true
				_on_pivot(forward(), speed / run)
		else:
			var rate := deg_to_rad(lerpf(f.turn_rate_slow_deg, f.turn_rate_run_deg, clampf(speed / run, 0.0, 1.0)))
			var omega := clampf(diff * f.turn_sharpness, -rate, rate)
			rotation.y += clampf(omega * dt, -absf(diff), absf(diff))
			var align := maxf(cos(minf(absf(angle_difference(rotation.y, yaw_for(want))), PI * 0.5)), 0.0)
			target_speed = dir.length() * max_speed * speed_multiplier * align
			if absf(diff) < deg_to_rad(20.0):
				_pivoting = false
	else:
		_pivoting = false
	if has_input and not _move_input_prev and speed < 0.5 and dir.length() > 0.8:
		alive.run_start(dir.normalized())
	elif not has_input and _move_input_prev and speed > run * 0.85:
		alive.skid(0.45, move_velocity / speed)
	_move_input_prev = has_input
	if braking:
		speed = _approach(speed, 0.0, f.decel_sharpness, f.decel_linear * f.brake_mult, dt)
	elif target_speed >= speed:
		speed = _approach(speed, target_speed, f.accel_sharpness, f.accel_linear, dt)
	else:
		speed = _approach(speed, target_speed, f.decel_sharpness, f.decel_linear, dt)
	move_velocity = forward() * speed
	animator.set_locomotion(speed, run, f.speed_matched_locomotion)


static func _approach(v: float, target: float, sharpness: float, linear: float, dt: float) -> float:
	if sharpness > 0.0:
		v = lerpf(v, target, 1.0 - exp(-sharpness * dt))
	return move_toward(v, target, linear * dt)


func _turn_to(dir: Vector3, sharpness: float, dt: float) -> void:
	if sharpness > 0.0:
		face_smooth(dir, sharpness, feel.turn_rate_deg, dt)
	else:
		face_toward(dir, feel.turn_rate_deg, dt)


## Sharp reversal at speed: plant and pivot (lean back, skid dust, scuff).
func _on_pivot(old_dir: Vector3, strength: float) -> void:
	alive.skid(strength, old_dir)


## Smear: on the active frames of a swing the trail burns brighter (FeelPreset.smear).
func set_smear(on: bool) -> void:
	on = on and feel.smear
	if on == _smear_on:
		return
	_smear_on = on
	trail.set_intensity(trail.intensity * (1.25 if on else 1.0 / 1.25))


## Disables collisions with enemy bodies (dodging through swarms) - both ways: the
## enemies also stop colliding with the hero, otherwise their move_and_slide pushes them
## out of the rolling capsule and the roll drags them along. Only masks that had the
## player bit are restored.
func set_enemy_collision(enabled: bool) -> void:
	set_collision_mask_value(3, enabled)
	if not enabled:
		for n in get_tree().get_nodes_in_group(&"enemies"):
			var e := n as CollisionObject3D
			if e != null and e.get_collision_mask_value(2) and not _released_enemies.has(e):
				e.set_collision_mask_value(2, false)
				_released_enemies.append(e)
	else:
		for e in _released_enemies:
			if is_instance_valid(e):
				e.set_collision_mask_value(2, true)
		_released_enemies.clear()


# --- aiming ---------------------------------------------------------------------

## Raw aim: cursor / right stick, else movement input, else facing.
func raw_aim_direction() -> Vector3:
	if lock_on.target != null:
		return direction_to_node(lock_on.target)
	var a := input.aim_direction(global_position)
	if a != Vector3.ZERO:
		return a
	var m := input.move_world()
	if m.length() > 0.2:
		return m.normalized()
	return forward()


## Attack direction with soft aim assist: rotates toward the closest enemy inside
## the assist cone and returns the extra step distance toward it.
## Returns {"dir": Vector3, "step": float, "target": Node3D}
func attack_aim(max_range: float = -1.0) -> Dictionary:
	var dir := raw_aim_direction()
	var result := {"dir": dir, "step": 0.0, "target": null}
	if not balance.aim_assist_enabled:
		return result
	var rng := balance.aim_assist_range if max_range < 0.0 else max_range
	var half_cone := deg_to_rad(balance.aim_assist_angle * 0.5)
	var best: Combatant = lock_on.target as Combatant
	var best_score := INF
	if best == null:
		for n in get_tree().get_nodes_in_group(&"enemies"):
			var e := n as Combatant
			if e == null or not e.is_targetable():
				continue
			var to := e.global_position - global_position
			to.y = 0.0
			var d := to.length()
			if d > rng + e.body_radius or d < 0.01:
				continue
			var ang := absf(dir.signed_angle_to(to.normalized(), Vector3.UP))
			if ang > half_cone:
				continue
			var score := d + ang * 2.0
			if score < best_score:
				best_score = score
				best = e
	if best == null:
		return result
	var to_t := best.global_position - global_position
	to_t.y = 0.0
	var dist := to_t.length()
	if dist > 0.01:
		var assisted := dir.slerp(to_t.normalized(), balance.aim_assist_strength).normalized()
		if lock_on.target != null:
			assisted = to_t.normalized()
		result["dir"] = assisted
		var stop := balance.aim_assist_stop_distance + best.body_radius
		result["step"] = clampf(dist - stop, 0.0, balance.aim_assist_step)
		result["target"] = best
	return result


# --- action gating -------------------------------------------------------------------

## Starts a buffered action if allowed. Returns true if a transition happened.
## flags: "attack", "dodge", "ranged", "heal", "interact"
func try_actions(flags: Dictionary) -> bool:
	if bool(flags.get("dodge", false)) and input.peek(&"dodge"):
		if has_stamina():
			input.consume(&"dodge")
			fsm.transition_to(&"Dodge")
			return true
	if bool(flags.get("attack", false)):
		if input.peek(&"attack_light") and has_stamina():
			input.consume(&"attack_light")
			fsm.transition_to(&"Attack", {"index": int(flags.get("next_index", 0))})
			return true
		if input.peek(&"attack_heavy") and has_stamina():
			input.consume(&"attack_heavy")
			fsm.transition_to(&"Heavy")
			return true
	if bool(flags.get("ranged", false)) and input.peek(&"ranged"):
		input.consume(&"ranged")
		if can_cast():
			fsm.transition_to(&"Cast")
			return true
		AudioManager.play_event(&"no_energy")
	if bool(flags.get("heal", false)) and input.peek(&"heal"):
		input.consume(&"heal")
		if ankh > 0 and health.current < health.max_health:
			fsm.transition_to(&"Heal")
			return true
		AudioManager.play_event(&"ui_deny")
	if bool(flags.get("interact", false)) and input.peek(&"interact"):
		input.consume(&"interact")
		if interactable != null and is_instance_valid(interactable) and bool(interactable.call(&"can_interact", self)):
			interactable.call(&"interact", self)
			return true
	return false


func handle_lock_input() -> void:
	if input.consume(&"lock_on"):
		lock_on.toggle()
	if lock_on.target != null:
		if input.consume(&"target_next"):
			lock_on.switch_target(1)
		elif input.consume(&"target_prev"):
			lock_on.switch_target(-1)
		var flick := input.consume_flick()
		if flick != Vector2.ZERO:
			lock_on.switch_target(1 if flick.x >= 0.0 else -1)
	else:
		input.consume(&"target_next")
		input.consume(&"target_prev")


# --- interaction -----------------------------------------------------------------

func _on_interact_area_changed() -> void:
	var best: Node = null
	var best_d := INF
	for a in interact_area.get_overlapping_areas():
		var it := a as Node
		if it == null or not it.has_method(&"can_interact"):
			continue
		if not bool(it.call(&"can_interact", self)):
			continue
		var d := (a as Node3D).global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = it
	if best != interactable:
		interactable = best
		interact_target_changed.emit(interactable)


func refresh_interactable() -> void:
	_on_interact_area_changed()


# --- combat reactions -------------------------------------------------------------

func _modify_incoming_damage(hit: HitInfo) -> float:
	return hit.damage * balance.enemy_damage_mult


func _on_hit_received(hit: HitInfo) -> void:
	if is_dead:
		return
	super._on_hit_received(hit)
	if god_mode:
		health.heal(hit.damage)
	resources_changed.emit()
	if hit.is_dot:
		return
	var p := global_position + Vector3.UP * 1.1
	Vfx.shards(p, -hit.direction + Vector3.UP * 0.4, 14 if hit.is_heavy else 9)
	Vfx.hit_sparks(p, hit.direction, hit.is_heavy)
	AudioManager.play_event(&"player_hurt", p)
	CameraShake.add_trauma(balance.shake_on_player_hurt + (0.2 if hit.is_heavy else 0.0))
	# Taking a blow lands too: the view is shoved along it and the pad rumbles.
	if feel.camera_kick > 0.0 and game_camera != null:
		game_camera.kick(hit.direction, feel.camera_kick * (1.4 if hit.is_heavy else 0.9))
	if feel.rumble and input.using_gamepad:
		Input.start_joy_vibration(0, 0.6 if hit.is_heavy else 0.35, 1.0 if hit.is_heavy else 0.6, hit.hitstop + 0.12)


func _react_to_hit(hit: HitInfo) -> void:
	if hit.is_dot:
		return
	grant_iframes(stats.hurt_iframes)
	if fsm.current != null and not fsm.current.can_be_interrupted():
		return
	if hit.is_grab:
		return
	fsm.transition_to(&"Hurt", {"heavy": hit.is_heavy or hit.knockback >= 7.0})


func _on_death(_hit: HitInfo) -> void:
	fsm.transition_to(&"Dead")


func _on_hit_landed(target: Node3D, hit: HitInfo) -> void:
	if hit.was_blocked_by_iframes:
		return
	if hit.attack != null and not hit.is_projectile:
		add_energy(hit.attack.energy_gain)
	# Hit confirm: the attack can now be dodge-cancelled (FeelPreset.dodge_cancel_on_hit).
	if fsm.current != null and fsm.current.has_method(&"on_hit_confirmed"):
		fsm.current.call(&"on_hit_confirmed")
	var amount := hit.shake * (1.4 if hit.is_heavy else 1.0) * feel.shake_mult
	var heavy := hit.is_heavy or hit.hitstop >= 0.12
	# One impact per physics frame, even when a swing hits several enemies.
	if Engine.get_physics_frames() != _last_shake_frame:
		_last_shake_frame = Engine.get_physics_frames()
		CameraShake.add_trauma(amount)
		_impact(hit, heavy)
	if target is Combatant:
		var c := target as Combatant
		c.motion.stretch_impulse(-0.12)
		if hit.killed and not hit.is_projectile:
			# Killing blow: hold the freeze a little longer on the hero.
			apply_hitstop(hitstop_left + 0.05)


## What the hero feels when the blade connects (FeelPreset "Impact"): the swing is
## dragged for a moment after the freeze, the body jolts back, the camera is kicked
## along the blow and a gamepad rumbles.
func _impact(hit: HitInfo, heavy: bool) -> void:
	if hit.is_projectile:
		return
	var f := feel
	if f.hit_drag_time > 0.0:
		apply_hit_drag(f.hit_drag_time * (1.4 if heavy else 1.0), f.hit_drag_factor)
	if f.attacker_recoil > 0.0:
		motion.recoil(-hit.direction, f.attacker_recoil * (1.5 if heavy else 1.0))
	if f.camera_kick > 0.0 and game_camera != null:
		game_camera.kick(hit.direction, f.camera_kick * (1.6 if heavy else 1.0))
	if f.rumble and input.using_gamepad:
		var stop := hit.hitstop + 0.06
		Input.start_joy_vibration(0, 0.45 if heavy else 0.25, 0.9 if heavy else 0.5, stop)


func _footstep(side: StringName) -> void:
	if not is_on_floor():
		return
	# Walk and run blend in sync, so both clips report the same step: keep one.
	var now := Time.get_ticks_msec()
	if now - int(_last_step_msec.get(side, 0)) < 120:
		return
	_last_step_msec[side] = now
	footstep_side.emit(side)
	_step_toggle = not _step_toggle
	var ev := &"footstep_stone" if global_position.y < -1.0 else &"footstep_sand"
	AudioManager.play_event(ev, global_position)
	var speed := move_velocity.length()
	if feel.footstep_dust and side != &"" and speed > 2.5:
		Vfx.dust(foot_position(side), 2, 0.45 + 0.25 * clampf(speed / run_speed(), 0.0, 1.0))
		# Footfall: a little weight lands on each step.
		motion.land_squash(0.06 * feel.squash * clampf(speed / run_speed(), 0.0, 1.0))
	elif not feel.footstep_dust and speed > 4.0 and _step_toggle:
		Vfx.dust(global_position, 3, 0.7)


## World position of a foot on the ground (rig bone if there is one).
func foot_position(side: StringName) -> Vector3:
	var pr := rig as PlaceholderRig
	if pr != null:
		var n := pr.bones.get("FootR" if side == &"r" else "FootL") as Node3D
		if n != null:
			return Vector3(n.global_position.x, global_position.y, n.global_position.z)
	return global_position


## Spawns the Eye of Ra projectile from the left hand.
func fire_eye_of_ra(dir: Vector3) -> void:
	var proj := RA_PROJECTILE.instantiate() as Projectile
	var origin := rig.get_socket(&"hand_l").global_position
	origin.y = global_position.y + 1.1
	proj.setup_ra(self, stats.ranged_attack, GameState.spirit_damage_multiplier(), dir, stats.ranged_projectile_speed, stats.ranged_range)
	get_tree().current_scene.add_child(proj)
	proj.global_position = origin
	proj.reset_physics_interpolation()


# --- respawn ------------------------------------------------------------------------

func respawn_at(pos: Vector3, yaw: float) -> void:
	is_dead = false
	hurtbox.monitorable = true
	teleport_to(pos, yaw)
	refresh_stats(true)
	energy = 0.0
	invulnerable_time = 1.0
	hazard_count = 0
	speed_multiplier = 1.0
	lock_on.release()
	input.clear_buffer()
	fsm.transition_to(&"Move")
	animator.play_locomotion()
	resources_changed.emit()


func notify_death_finished() -> void:
	death_finished.emit()


## Desired camera look-ahead. Movement lead holds after the input is released (the camera
## does not drift when the hero stops) and recentres after camera_recenter_delay.
func camera_look_ahead() -> Vector3:
	var m := input.move_world()
	if m.length() > 0.1:
		_look_ahead_hold = m * feel.camera_look_ahead
		_look_ahead_idle = 0.0
	else:
		_look_ahead_idle += get_process_delta_time()
		if _look_ahead_idle > feel.camera_recenter_delay:
			_look_ahead_hold = Vector3.ZERO
	var la := _look_ahead_hold
	if lock_on.target != null and is_instance_valid(lock_on.target):
		var to := lock_on.target.global_position - global_position
		to.y = 0.0
		la += to.limit_length(14.0) * 0.35
	else:
		var a := input.aim_direction(global_position)
		la += a * 1.4
	return la


func get_debug_state() -> String:
	return "PLAYER %s  hp %d  st %d  en %.2f  ankh %d%s" % [fsm.current_name(), int(health.current), int(stamina), energy, ankh,
		"  [lock %s]" % lock_on.target.name if lock_on.target != null else ""]
