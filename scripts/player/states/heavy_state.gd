extends PlayerState
## Heavy attack: windup, optional charge while the button is held (up to
## heavy_max_charge seconds, damage scales to heavy_charge_damage_mult), release.
## Windows: the windup and the charge can be dodge-cancelled (FeelPreset
## heavy_windup_dodge_cancel); after the release, dodge from cancel_delay into the
## recovery (or right after the swing connects), next attack from chain_delay, walking
## out after walk_out_recovery. The lunge eases out and keeps the momentum of a run.

enum Phase { WINDUP, CHARGE, ACTIVE, RECOVERY }

const PRE := 0.03

var attack: AttackData
var phase: Phase = Phase.WINDUP
var charge: float = 0.0
var _dir: Vector3 = Vector3.FORWARD
var _step: float = 0.0
var _carry: float = 0.0
var _release_t: float = 0.0
var _full_flashed: bool = false
var _hit: bool = false


func enter(_msg: Dictionary) -> void:
	attack = player.stats.heavy_attack
	player.spend_stamina(attack.stamina_cost)
	_dir = player.attack_aim()["dir"]
	_carry = maxf(player.move_velocity.dot(_dir), 0.0) * player.feel.attack_entry_keep
	player.face_instant(_dir)
	player.animator.play(&"heavy_windup", true)
	player.motion.anticipate(1.2)
	player.alive.add_exertion(0.15)
	phase = Phase.WINDUP
	charge = 0.0
	_full_flashed = false
	_hit = false


func exit() -> void:
	player.set_smear(false)
	player.hitbox.deactivate()
	player.trail.emitting = false
	player.trail.set_intensity(3.2)


## Hyper armour from the end of the windup to the end of the active frames.
func can_be_interrupted() -> bool:
	return phase == Phase.WINDUP or phase == Phase.RECOVERY


func on_hit_confirmed() -> void:
	_hit = true


func _since_release() -> float:
	return time_in_state - _release_t + EPS


func accepts(kind: StringName) -> bool:
	var f := player.feel
	match phase:
		Phase.WINDUP, Phase.CHARGE:
			return kind == &"dodge" and f.heavy_windup_dodge_cancel
		_:
			var r := _since_release() - PRE - attack.active
			match kind:
				&"dodge":
					return r >= attack.cancel_delay or (_hit and f.dodge_cancel_on_hit)
				&"attack":
					return r >= attack.chain_delay
				&"move":
					return r >= attack.recovery * f.walk_out_recovery
	return false


func windows() -> Dictionary:
	var a := attack.active
	var r := attack.recovery
	if phase == Phase.WINDUP or phase == Phase.CHARGE:
		var span := attack.windup + player.stats.heavy_max_charge
		var marks := {"dodge": 0.0} if player.feel.heavy_windup_dodge_cancel else {}
		return {"name": "heavy (charge)", "t": time_in_state, "total": span,
			"phases": [[attack.windup, Color(1.0, 0.85, 0.3)], [player.stats.heavy_max_charge, Color(1.0, 0.6, 0.2)]], "marks": marks}
	return {"name": "heavy (release)", "t": _since_release(), "total": PRE + a + r,
		"phases": [[PRE, Color(1.0, 0.85, 0.3)], [a, Color(1.0, 0.25, 0.2)], [r, Color(0.45, 0.55, 0.7)]],
		"marks": {"dodge": PRE + a + attack.cancel_delay, "attack": PRE + a + attack.chain_delay, "move": PRE + a + r * player.feel.walk_out_recovery}}


func physics_update(dt: float) -> void:
	var f := player.feel
	if (phase == Phase.WINDUP or phase == Phase.CHARGE) and accepts(&"dodge") and player.try_actions({"dodge": true}):
		return
	match phase:
		Phase.WINDUP:
			player.move_velocity = _dir * _carry * exp(-f.attack_entry_decay * time_in_state)
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
			var since := _since_release()
			var span := PRE + attack.active
			if since < span and _step > 0.0:
				var u := clampf(since / span, 0.0, 1.0)
				var p := maxf(f.lunge_ease, 1.0)
				player.move_velocity = _dir * (_step * p * pow(1.0 - u, p - 1.0) / span)
			else:
				player.move_velocity = player.move_velocity.move_toward(Vector3.ZERO, 50.0 * dt)
			if phase == Phase.ACTIVE and since >= span + 0.05:
				_deactivate()
			if phase == Phase.RECOVERY or _hit:
				if accepts(&"dodge") and player.try_actions({"dodge": true}):
					return
			if phase == Phase.RECOVERY:
				if accepts(&"attack") and player.try_actions({"attack": true, "ranged": true}):
					return
				if since >= span + attack.recovery:
					transition(&"Move")
					return
				if accepts(&"move") and player.input.move_world().length() > 0.3:
					transition(&"Move")


func _track_aim(dt: float, rate: float) -> void:
	var a := player.raw_aim_direction()
	player.face_toward(a, rate, dt)
	_dir = player.forward()


func _release() -> void:
	var aim := player.attack_aim()
	_dir = (aim["dir"] as Vector3).lerp(player.forward(), 0.3).normalized()
	player.face_instant(_dir)
	_step = attack.lunge_distance * player.feel.lunge_scale + float(aim["step"]) \
		+ (_carry / maxf(player.feel.attack_entry_decay, 0.1) if charge <= 0.0 else 0.0)
	phase = Phase.ACTIVE
	_release_t = time_in_state
	player.animator.play(&"heavy_release", true)
	player.motion.stretch_impulse(0.2)
	var k := clampf(charge / maxf(player.stats.heavy_max_charge, 0.01), 0.0, 1.0)
	player.set_meta(&"heavy_charge_k", k)
	player.trail.set_intensity(3.2 + k * 3.0)
	player.hitbox.activate(attack, player.melee_multiplier() * lerpf(1.0, player.stats.heavy_charge_damage_mult, k))
	player.trail.emitting = true
	player.set_smear(true)
	AudioManager.play_event(&"heavy_swing", player.global_position + Vector3.UP)


func _deactivate() -> void:
	if phase != Phase.ACTIVE:
		return
	phase = Phase.RECOVERY
	player.set_smear(false)
	player.hitbox.deactivate()
	player.trail.emitting = false


func on_anim_event(event: StringName, tag: StringName) -> void:
	if tag == &"heavy_release" and event == &"hitbox_off":
		_deactivate()
