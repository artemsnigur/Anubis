extends PlayerState
## "Ankh" heal: the charge is consumed immediately, health is restored at the
## clip's heal_apply event. Getting hit before that wastes the charge (punishable).

var _applied: bool = false


func enter(_msg: Dictionary) -> void:
	player.ankh -= 1
	player.resources_changed.emit()
	_applied = false
	player.animator.play(&"heal", true)
	AudioManager.play_event(&"heal_start", player.global_position)
	player.flash_fx.flash(Color(0.3, 1.0, 0.8), 0.6, 0.25)


func physics_update(dt: float) -> void:
	var s := player.stats
	player.locomote(player.input.move_world(), s.heal_move_speed, dt)
	if not _applied and time_in_state >= s.heal_apply_time + 0.05:
		_apply()
	if time_in_state >= s.heal_duration:
		transition(&"Move")


func on_anim_event(event: StringName, tag: StringName) -> void:
	if tag == &"heal" and event == &"heal_apply":
		_apply()


func _apply() -> void:
	if _applied:
		return
	_applied = true
	player.health.heal(player.health.max_health * player.stats.heal_fraction)
	player.resources_changed.emit()
	var p := player.global_position + Vector3.UP
	Vfx.motes(p, 24)
	Vfx.ring(player.global_position, 0.3, 2.2, 0.5, Color(0.3, 1.0, 0.8))
	Vfx.light_flash(p, Color(0.4, 1.0, 0.8), 3.0, 5.0, 0.5)
	AudioManager.play_event(&"heal", p)
	player.flash_fx.flash(Color(0.4, 1.0, 0.8), 0.35, 0.6)
