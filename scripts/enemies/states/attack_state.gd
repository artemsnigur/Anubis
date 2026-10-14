extends EnemyState
## Generic attack executor: windup (tracking + telegraph) -> active (hitbox + movement,
## or a special move implemented by the enemy) -> recovery, with combo chaining.
## Hitbox on/off come from the clip's method track; time fallback keeps it robust.

enum Phase { WINDUP, ACTIVE, RECOVERY }

var attack: EnemyAttackData
var phase: Phase = Phase.WINDUP
var _t: float = 0.0
var _active_t: float = 0.0
var _telegraphed: bool = false
var _special: bool = false
var _recovery_len: float = 0.0
var _next: EnemyAttackData


func enter(msg: Dictionary) -> void:
	_start(msg.get("attack") as EnemyAttackData)


func _start(a: EnemyAttackData) -> void:
	attack = a
	phase = Phase.WINDUP
	_t = 0.0
	_active_t = 0.0
	_telegraphed = false
	_special = false
	_next = null
	enemy.animator.play(attack.anim, true)
	enemy.start_cooldown(attack)


func exit() -> void:
	enemy.hitbox.deactivate()
	if attack != null:
		enemy.attack_end(attack)
	enemy.release_token()


func can_be_interrupted() -> bool:
	return true


func physics_update(dt: float) -> void:
	_t += dt
	match phase:
		Phase.WINDUP:
			enemy.stop(dt, 30.0)
			enemy.face_player(dt, attack.tracking_deg)
			if not _telegraphed and _t >= attack.windup - attack.telegraph_lead:
				_telegraph()
			if _t >= attack.windup + 0.05:
				_begin_active()
		Phase.ACTIVE:
			_active_t += dt
			var running := false
			if _special:
				running = enemy.attack_update_active(attack, _active_t, dt)
			else:
				_generic_movement(dt)
			if not running and _active_t >= attack.active + 0.05:
				_end_active()
		Phase.RECOVERY:
			enemy.stop(dt, 20.0)
			var r := _t
			if _next != null:
				enemy.face_player(dt, attack.tracking_deg)
				if r >= attack.combo_gap:
					_start(_next)
				return
			if r >= _recovery_len:
				transition(&"Strafe")


func on_anim_event(event: StringName, tag: StringName) -> void:
	if attack == null or tag != attack.anim:
		return
	match event:
		&"telegraph":
			_telegraph()
		&"hitbox_on":
			_begin_active()
		&"hitbox_off":
			if not _special:
				_end_active()
		&"swing":
			AudioManager.play_event(&"enemy_swing", enemy.global_position + Vector3.UP)


func _telegraph() -> void:
	if _telegraphed:
		return
	_telegraphed = true
	enemy.telegraph(attack)


func _begin_active() -> void:
	if phase != Phase.WINDUP:
		return
	if not _telegraphed:
		_telegraph()
	phase = Phase.ACTIVE
	_active_t = 0.0
	_special = enemy.attack_begin_active(attack)
	if not _special:
		enemy.hitbox.activate(attack, GameState.balance.enemy_damage_mult)


func _generic_movement(dt: float) -> void:
	match attack.move_type:
		EnemyAttackData.MoveType.LUNGE, EnemyAttackData.MoveType.GRAB:
			if _active_t <= attack.move_duration:
				enemy.move_velocity = enemy.forward() * attack.move_speed
			else:
				enemy.stop(dt, 40.0)
		EnemyAttackData.MoveType.SPIN:
			enemy.stop(dt, 40.0)
			enemy.rotation.y += TAU / maxf(attack.active, 0.05) * dt
		_:
			enemy.stop(dt, 40.0)


func _end_active() -> void:
	if phase != Phase.ACTIVE:
		return
	phase = Phase.RECOVERY
	enemy.hitbox.deactivate()
	_t = 0.0
	_recovery_len = attack.recovery
	_next = enemy.combo_follow_up(attack)
	if _next != null and not enemy.player_alive():
		_next = null
