extends PlayerState
## Light attack chain (3 hits). All windows are in state time, which runs in lock-step
## with the clip (the state's first update happens in the tick the input arrives):
##   windup   [0, w)      anticipation pose from the first frame; the first
##                        windup_steer_time seconds can still be re-aimed (+ magnetism)
##   active   [w, w+a)    hitbox on (clip event, time fallback); ease-out lunge that
##                        carries the momentum of a run
##   recovery [w+a, T)    dodge from w+a+cancel_delay - or right after a hit connects;
##                        next attack at w+a+chain_delay (a press from mid-active on is
##                        queued and never expires); walk out after walk_out_recovery.

enum Phase { WINDUP, ACTIVE, RECOVERY }

var attack: AttackData
var index: int = 0
var phase: Phase = Phase.WINDUP
var _dir: Vector3 = Vector3.FORWARD
var _step: float = 0.0
var _carry: float = 0.0
var _queued: bool = false
var _queued_dodge: bool = false
var _hit: bool = false


func enter(msg: Dictionary) -> void:
	var list := player.stats.light_attacks
	index = int(msg.get("index", 0)) % list.size()
	attack = list[index]
	player.spend_stamina(attack.stamina_cost)
	var f := player.feel
	var entry := player.move_velocity
	var aim := player.attack_aim()
	_dir = aim["dir"]
	_step = attack.lunge_distance * f.lunge_scale + float(aim["step"])
	_carry = maxf(entry.dot(_dir), 0.0) * f.attack_entry_keep
	player.face_instant(_dir)
	player.anim_speed = f.attack_tempo
	player.animator.play(attack.anim, true)
	player.motion.anticipate(0.6 if index < 2 else 1.0)
	player.alive.add_exertion(0.08)
	phase = Phase.WINDUP
	_queued = false
	_queued_dodge = false
	_hit = false


func exit() -> void:
	player.anim_speed = 1.0
	player.hitbox.deactivate()
	player.trail.emitting = false
	player.set_smear(false)


func accepts(kind: StringName) -> bool:
	var end_active := attack.windup + attack.active
	match kind:
		&"dodge":
			return reached(end_active + attack.cancel_delay) or (_hit and player.feel.dodge_cancel_on_hit)
		&"attack":
			return reached(end_active + attack.chain_delay)
		&"move":
			return reached(end_active + attack.recovery * player.feel.walk_out_recovery)
	return false


func windows() -> Dictionary:
	var w := attack.windup
	var a := attack.active
	var r := attack.recovery
	return {"name": String(attack.anim), "t": time_in_state, "total": w + a + r,
		"phases": [[w, Color(1.0, 0.85, 0.3)], [a, Color(1.0, 0.25, 0.2)], [r, Color(0.45, 0.55, 0.7)]],
		"marks": {"dodge": w + a + attack.cancel_delay, "attack": w + a + attack.chain_delay,
			"move": w + a + r * player.feel.walk_out_recovery, "queue": w + a * maxf(player.feel.combo_queue_from_active, 0.0)}}


func on_hit_confirmed() -> void:
	_hit = true


func physics_update(dt: float) -> void:
	var t := time_in_state
	var f := player.feel
	if phase == Phase.WINDUP and t <= f.windup_steer_time:
		var aim := player.attack_aim()
		player.face_toward(aim["dir"], 1440.0, dt)
		_dir = player.forward()
	_move_body(t, dt)
	# Time-based fallback in case a clip lacks events.
	if phase == Phase.WINDUP and t >= attack.windup + 0.05:
		_activate()
	if phase == Phase.ACTIVE and t >= attack.windup + attack.active + 0.05:
		_deactivate()
	# Combo queue: from mid-active a press is kept until its window opens - the next
	# attack at the chain point, a dodge at the dodge-cancel point (committed, not lost).
	if f.combo_queue_from_active >= 0.0 and reached(attack.windup + attack.active * f.combo_queue_from_active):
		if player.input.consume(&"attack_light"):
			_queued = true
			_queued_dodge = false
		if not accepts(&"dodge") and player.input.consume(&"dodge"):
			_queued_dodge = true
			_queued = false
	if accepts(&"dodge"):
		if _queued_dodge:
			player.input.push(&"dodge")
			_queued_dodge = false
		if player.try_actions({"dodge": true}):
			return
	var next := (index + 1) % player.stats.light_attacks.size()
	if accepts(&"attack"):
		if _queued and player.has_stamina():
			transition(&"Attack", {"index": next})
			return
		if player.try_actions({"attack": true, "ranged": true, "next_index": next}):
			return
	if reached(attack.total_time()):
		transition(&"Move")
		return
	if accepts(&"move") and player.input.move_world().length() > 0.3:
		transition(&"Move")


## Momentum of the entry run (decaying) + ease-out lunge over [lunge_start * w, w + a].
## State time runs at attack_tempo, so the lunge speed is scaled by it as well.
func _move_body(t: float, dt: float) -> void:
	var f := player.feel
	var v := _dir * _carry * exp(-f.attack_entry_decay * t / maxf(player.anim_speed, 0.01))
	var t0 := attack.windup * f.lunge_start
	var t1 := attack.windup + attack.active
	if t >= t0 and t < t1 and _step > 0.0:
		var span := t1 - t0
		var u := (t - t0) / span
		var p := maxf(f.lunge_ease, 1.0)
		v += _dir * (_step * p * pow(1.0 - u, p - 1.0) / span) * player.anim_speed
		player.move_velocity = v
	elif t < t0:
		player.move_velocity = v
	else:
		player.move_velocity = player.move_velocity.move_toward(Vector3.ZERO, 60.0 * dt)


func on_anim_event(event: StringName, tag: StringName) -> void:
	if tag != attack.anim:
		return
	match event:
		&"swing":
			AudioManager.play_event(&"light_swing", player.global_position + Vector3.UP)
		&"trail_on":
			player.trail.emitting = true
		&"hitbox_on":
			_activate()
		&"hitbox_off":
			_deactivate()


func _activate() -> void:
	if phase != Phase.WINDUP:
		return
	phase = Phase.ACTIVE
	player.trail.emitting = true
	player.set_smear(true)
	player.hitbox.activate(attack, player.melee_multiplier())


func _deactivate() -> void:
	if phase != Phase.ACTIVE:
		return
	phase = Phase.RECOVERY
	player.hitbox.deactivate()
	player.set_smear(false)
	get_tree().create_timer(0.05, false).timeout.connect(func() -> void:
		if not player.fsm.is_in(&"Attack") or phase == Phase.RECOVERY:
			player.trail.emitting = false)
