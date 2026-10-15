extends PlayerState
## "Eye of Ra": spends one solar charge and fires a sun bolt from the left hand.

var attack: AttackData
var _fired: bool = false
var _dir: Vector3 = Vector3.FORWARD


func enter(_msg: Dictionary) -> void:
	attack = player.stats.ranged_attack
	player.energy = maxf(player.energy - 1.0, 0.0)
	player.resources_changed.emit()
	_dir = player.attack_aim(player.stats.ranged_range * 0.6)["dir"]
	player.face_instant(_dir)
	player.move_velocity *= 0.3
	player.anim_speed = player.feel.attack_tempo
	player.animator.play(&"cast", true)
	_fired = false
	Vfx.glint(player.global_position + Vector3.UP * 1.3, Color(1.0, 0.8, 0.35), 0.9, 0.2)


func exit() -> void:
	player.anim_speed = 1.0


func physics_update(dt: float) -> void:
	player.move_velocity = player.move_velocity.move_toward(Vector3.ZERO, 40.0 * dt)
	if not _fired:
		player.face_toward(player.raw_aim_direction(), 720.0, dt)
		if time_in_state >= attack.windup + 0.05:
			_fire()
		return
	if accepts(&"dodge") and player.try_actions({"dodge": true, "attack": true}):
		return
	if time_in_state >= attack.total_time():
		transition(&"Move")


func accepts(kind: StringName) -> bool:
	if not _fired:
		return false
	var r := time_in_state - attack.windup - attack.active
	return (kind == &"dodge" or kind == &"attack") and r >= attack.cancel_delay


func windows() -> Dictionary:
	var w := attack.windup
	var a := attack.active
	return {"name": "eye of ra", "t": time_in_state, "total": attack.total_time(),
		"phases": [[w, Color(1.0, 0.85, 0.3)], [a, Color(1.0, 0.25, 0.2)], [attack.recovery, Color(0.45, 0.55, 0.7)]],
		"marks": {"dodge": w + a + attack.cancel_delay, "attack": w + a + attack.cancel_delay, "move": attack.total_time()}}


func on_anim_event(event: StringName, tag: StringName) -> void:
	if tag == &"cast" and event == &"cast_fire":
		_fire()


func _fire() -> void:
	if _fired:
		return
	_fired = true
	var aim := player.attack_aim(player.stats.ranged_range * 0.6)
	_dir = aim["dir"]
	player.face_instant(_dir)
	player.fire_eye_of_ra(_dir)
	player.motion.recoil(-_dir, 0.3)
	AudioManager.play_event(&"ra_cast", player.global_position + Vector3.UP)
	CameraShake.add_trauma(0.12)
