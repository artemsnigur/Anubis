extends EnemyState
## Noticed the player: short readable reaction (turn + alert pose + voice).


func enter(_msg: Dictionary) -> void:
	enemy.aware = true
	enemy.animator.play(&"alert", true)
	if enemy.voice_sound != &"":
		AudioManager.play_event(enemy.voice_sound, enemy.global_position)
	enemy.alert_allies()


func physics_update(dt: float) -> void:
	enemy.stop(dt)
	enemy.face_player(dt, 540.0)
	if time_in_state >= enemy.data.alert_time:
		transition(&"Chase")
