extends PlayerState
## Heavy attack: windup, optional charge while the button is held (up to
## heavy_max_charge seconds, damage scales to heavy_charge_damage_mult), release.

enum Phase { WINDUP, CHARGE, ACTIVE, RECOVERY }

var attack: AttackData
var phase: Phase = Phase.WINDUP
var charge: float = 0.0
var _dir: Vector3 = Vector3.FORWARD
var _step: float = 0.0
var _release_t: float = 0.0
var _full_flashed: bool = false


func enter(_msg: Dictionary) -> void:
	attack = player.stats.heavy_attack
	player.spend_stamina(attack.stamina_cost)
	_dir = player.attack_aim()["dir"]
	player.face_instant(_dir)
	player.move_velocity *= 0.2
	player.animator.play(&"heavy_windup", true)
	phase = Phase.WINDUP
	charge = 0.0
	_full_flashed = false


func exit() -> void:
	player.hitbox.deactivate()
	player.trail.emitting = false
	player.trail.set_intensity(1.6)


## Hyper armour from the end of the windup to the end of the active frames.
func can_be_interrupted() -> bool:
	return phase == Phase.WINDUP or phase == Phase.RECOVERY


func physics_update(dt: float) -> void:
	match phase:
		Phase.WINDUP:
			player.move_velocity = player.move_velocity.move_toward(Vector3.ZERO, 40.0 * dt)
			_track_aim(dt, 540.0)
			if time_in_state >= attack.windup:
				if player.input.is_held(&"attack_heavy") and player.stats.heavy_max_charge > 0.0:
					phase = Phase.CHARGE
					player.animator.play(&"heavy_charge", true)
				else:
					_release()
		Phase.CHARGE:
			charge += dt
			_track_aim(dt, 360.0)
			player.locomote(Vector3.ZERO, 0.0, dt, false)
			if charge >= player.stats.heavy_max_charge and not _full_flashed:
				_full_flashed = true
				Vfx.glint(player.rig.get_socket(&"trail_tip").global_position, Color(1.0, 0.85, 0.4), 1.4)
				AudioManager.play_event(&"charge_ready", player.global_position)
				player.flash_fx.flash(Color(1.0, 0.8, 0.3), 0.2, 0.6)
			if not player.input.is_held(&"attack_heavy") or charge >= player.stats.heavy_max_charge + 0.25:
				_release()
		Phase.ACTIVE, Phase.RECOVERY:
			var since := time_in_state - _release_t
			if since < 0.03 + attack.active and _step > 0.0:
				player.move_velocity = _dir * (_step / (0.03 + attack.active))
			else:
				player.move_velocity = player.move_velocity.move_toward(Vector3.ZERO, 50.0 * dt)
			if phase == Phase.ACTIVE and since >= 0.03 + attack.active + 0.05:
				_deactivate()
			if phase == Phase.RECOVERY:
				var r := since - 0.03 - attack.active
				if r >= attack.cancel_delay and player.try_actions({"dodge": true}):
					return
				if r >= attack.chain_delay and player.try_actions({"attack": true, "ranged": true}):
					return
				if since >= 0.03 + attack.active + attack.recovery:
					transition(&"Move")


func _track_aim(dt: float, rate: float) -> void:
	var a := player.raw_aim_direction()
	player.face_toward(a, rate, dt)
	_dir = player.forward()


func _release() -> void:
	var aim := player.attack_aim()
	_dir = (aim["dir"] as Vector3).lerp(player.forward(), 0.3).normalized()
	player.face_instant(_dir)
	_step = attack.lunge_distance + float(aim["step"])
	phase = Phase.ACTIVE
	_release_t = time_in_state
	player.animator.play(&"heavy_release", true)
	player.motion.stretch_impulse(0.2)
	var k := clampf(charge / maxf(player.stats.heavy_max_charge, 0.01), 0.0, 1.0)
	player.set_meta(&"heavy_charge_k", k)
	player.trail.set_intensity(1.6 + k * 1.6)
	player.hitbox.activate(attack, player.melee_multiplier() * lerpf(1.0, player.stats.heavy_charge_damage_mult, k))
	player.trail.emitting = true
	AudioManager.play_event(&"heavy_swing", player.global_position + Vector3.UP)


func _deactivate() -> void:
	if phase != Phase.ACTIVE:
		return
	phase = Phase.RECOVERY
	player.hitbox.deactivate()
	player.trail.emitting = false


func on_anim_event(event: StringName, tag: StringName) -> void:
	if tag == &"heavy_release" and event == &"hitbox_off":
		_deactivate()
