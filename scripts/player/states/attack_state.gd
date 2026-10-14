extends PlayerState
## Light attack chain (3 hits). Windup -> active (hitbox on, driven by the clip's
## method track) -> recovery with chain and dodge-cancel windows.

enum Phase { WINDUP, ACTIVE, RECOVERY }

var attack: AttackData
var index: int = 0
var phase: Phase = Phase.WINDUP
var _dir: Vector3 = Vector3.FORWARD
var _step: float = 0.0
var _active_at: float = 0.0


func enter(msg: Dictionary) -> void:
	var list := player.stats.light_attacks
	index = int(msg.get("index", 0)) % list.size()
	attack = list[index]
	player.spend_stamina(attack.stamina_cost)
	var aim := player.attack_aim()
	_dir = aim["dir"]
	_step = attack.lunge_distance + float(aim["step"])
	player.face_instant(_dir)
	player.move_velocity *= 0.25
	player.animator.play(attack.anim, true)
	phase = Phase.WINDUP
	_active_at = 0.0


func exit() -> void:
	player.hitbox.deactivate()
	player.trail.emitting = false


func physics_update(dt: float) -> void:
	var t := time_in_state
	# Lunge: distributed over the last 60 % of windup and the active window.
	var lunge_start := attack.windup * 0.4
	var lunge_end := attack.windup + attack.active
	if t >= lunge_start and t < lunge_end and _step > 0.0:
		player.move_velocity = _dir * (_step / (lunge_end - lunge_start))
	else:
		player.move_velocity = player.move_velocity.move_toward(Vector3.ZERO, 60.0 * dt)
	# Time-based fallback in case a clip lacks events.
	if phase == Phase.WINDUP and t >= attack.windup + 0.05:
		_activate()
	if phase == Phase.ACTIVE and t >= _active_at + attack.active + 0.05:
		_deactivate()
	if phase == Phase.RECOVERY:
		var r := t - attack.windup - attack.active
		if r >= attack.cancel_delay and player.input.peek(&"dodge"):
			if player.try_actions({"dodge": true}):
				return
		if r >= attack.chain_delay:
			if player.try_actions({"attack": true, "ranged": true, "next_index": (index + 1) % player.stats.light_attacks.size()}):
				return
		if t >= attack.total_time():
			transition(&"Move")
			return
		# Allow walking out of the tail of the recovery.
		if r > attack.recovery * 0.7 and player.input.move_world().length() > 0.3:
			transition(&"Move")


func on_anim_event(event: StringName, tag: StringName) -> void:
	if tag != attack.anim:
		return
	match event:
		&"swing":
			AudioManager.play_event(&"light_swing", player.global_position + Vector3.UP)
			player.trail.emitting = true
		&"hitbox_on":
			_activate()
		&"hitbox_off":
			_deactivate()


func _activate() -> void:
	if phase != Phase.WINDUP:
		return
	phase = Phase.ACTIVE
	_active_at = time_in_state
	player.trail.emitting = true
	player.hitbox.activate(attack, player.melee_multiplier())


func _deactivate() -> void:
	if phase != Phase.ACTIVE:
		return
	phase = Phase.RECOVERY
	player.hitbox.deactivate()
	player.trail.emitting = false
