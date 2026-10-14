class_name Mummy
extends EnemyBase
## Mummy Guardian: slow, tanky, high poise (hyper armour while attacking).
## Overhead slam + grab. The grab's red flash is the cue: dodge through it.
## A caught player is lifted, squeezed for three damage ticks and thrown.

const HOLD_TIME := 1.25
const SQUEEZE_TICKS := 3

var _grab_connected: bool = false
var _holding: bool = false
var _hold_t: float = 0.0
var _ticks_done: int = 0


func attack_begin_active(a: EnemyAttackData) -> bool:
	if a.move_type != EnemyAttackData.MoveType.GRAB:
		return false
	_grab_connected = false
	_holding = false
	_hold_t = 0.0
	_ticks_done = 0
	hitbox.grab_mode = true
	hitbox.activate(a, 1.0)
	return true


func attack_update_active(a: EnemyAttackData, t: float, dt: float) -> bool:
	if not _holding:
		if t <= a.move_duration:
			move_velocity = forward() * a.move_speed
		else:
			stop(dt, 40.0)
		if _grab_connected and player_alive():
			_start_hold()
			return true
		return t < a.active
	_hold_t += dt
	stop(dt, 40.0)
	var tick_every := HOLD_TIME / float(SQUEEZE_TICKS + 1)
	if _ticks_done < SQUEEZE_TICKS and _hold_t >= tick_every * float(_ticks_done + 1):
		_ticks_done += 1
		_squeeze(a)
	if _hold_t >= HOLD_TIME or not player_alive():
		_throw()
		return false
	return true


func _on_hit_landed(target: Node3D, hit: HitInfo) -> void:
	if hit.is_grab and target is Player and not hit.was_blocked_by_iframes:
		_grab_connected = true


func _start_hold() -> void:
	_holding = true
	hitbox.deactivate()
	hitbox.grab_mode = false
	animator.play(&"grab_hold", true)
	player.fsm.transition_to(&"Grabbed", {"grabber": self})
	AudioManager.play_event(&"mummy_groan", global_position, 3.0)
	CameraShake.add_trauma(0.3)


func _squeeze(a: EnemyAttackData) -> void:
	if not player_alive():
		return
	var h := HitInfo.from_attack(a, self, faction, GameState.balance.enemy_damage_mult / float(SQUEEZE_TICKS))
	h.is_grab = true
	h.knockback = 0.0
	h.direction = forward()
	h.position = player.global_position + Vector3.UP * 1.2
	player.hurtbox.invulnerable = false
	player.invulnerable_time = 0.0
	player.hurtbox.receive_hit(h)
	flash_fx.flash(Color(1.0, 0.3, 0.2), 0.15, 0.5)


func _throw() -> void:
	_holding = false
	if player_alive() and player.fsm.is_in(&"Grabbed"):
		var g := player.fsm.current
		g.call(&"release", forward())
		player.grant_iframes(0.6)
	CameraShake.add_trauma(0.35)


func attack_end(_a: EnemyAttackData) -> void:
	hitbox.grab_mode = false
	if _holding:
		_throw()
