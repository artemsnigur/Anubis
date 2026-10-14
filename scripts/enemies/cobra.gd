class_name Cobra
extends EnemyBase
## Cobra Priestess: keeps her distance and spits venom (clear windup: rearing back,
## hood flaring, green glint) that leaves a poison puddle. Retreats when approached.

const PROJECTILE := preload("res://scenes/combat/projectile.tscn")

var _retreat_cd: float = 0.0


func _combatant_ready() -> void:
	super._combatant_ready()
	telegraph_color = Color(0.5, 1.0, 0.3)


func _pre_update(dt: float, real_dt: float) -> void:
	super._pre_update(dt, real_dt)
	if _retreat_cd > 0.0:
		_retreat_cd -= dt


func strafe_special(_dt: float) -> bool:
	if _retreat_cd <= 0.0 and distance_to_player() < data.retreat_radius:
		_retreat_cd = 2.5
		fsm.transition_to(&"Retreat")
		return true
	return false


func attack_begin_active(a: EnemyAttackData) -> bool:
	if a.move_type != EnemyAttackData.MoveType.PROJECTILE:
		return false
	_spit(a)
	return true


func attack_update_active(_a: EnemyAttackData, _t: float, _dt: float) -> bool:
	return false


func _spit(a: EnemyAttackData) -> void:
	if not player_alive():
		return
	var mouth := rig.get_socket(&"mouth").global_position
	# Lead the target a little so strafing in a straight line is not free.
	var target := player.global_position + player.move_velocity * 0.35
	var proj := PROJECTILE.instantiate() as Projectile
	proj.setup_venom(self, a, mouth, target, a.move_speed)
	get_tree().current_scene.add_child(proj)
	proj.global_position = mouth
	proj.reset_physics_interpolation()
	AudioManager.play_event(&"spit", mouth)
	Vfx.venom_splash(mouth)
