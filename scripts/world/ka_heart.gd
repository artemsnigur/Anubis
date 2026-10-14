class_name KaHeart
extends Area3D
## The heart left behind on death, holding all carried Ka. Touch it to recover it.

var _visual: Node3D
var _t: float = 0.0
var _taken: bool = false
## Short arming delay: a heart spawned in the same frame the player teleports away
## would otherwise see the player's stale physics position.
var _arm_time: float = 0.5


func _ready() -> void:
	add_to_group(&"ka_heart")
	collision_layer = CombatTypes.LAYER_PICKUP
	collision_mask = CombatTypes.LAYER_PLAYER
	monitoring = true
	monitorable = false
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 1.0
	cs.shape = s
	cs.position = Vector3.UP * 0.8
	add_child(cs)
	_visual = Node3D.new()
	_visual.position = Vector3.UP * 1.1
	add_child(_visual)
	var mat := Mats.get_mat(&"heart_glow")
	Kit.mesh(_visual, PlaceholderRig.sphere(0.17), mat, Vector3(0.1, 0.06, 0), Vector3.ZERO, Vector3.ONE, false)
	Kit.mesh(_visual, PlaceholderRig.sphere(0.17), mat, Vector3(-0.1, 0.06, 0), Vector3.ZERO, Vector3.ONE, false)
	Kit.mesh(_visual, PlaceholderRig.cylinder(0.24, 0.0, 0.34, 12), mat, Vector3(0, -0.12, 0), Vector3.ZERO, Vector3(1.0, 1.0, 0.75), false)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.3, 0.25)
	light.light_energy = 2.0
	light.omni_range = 5.0
	light.position = Vector3.UP * 1.1
	add_child(light)


func _process(delta: float) -> void:
	_t += delta
	var beat := 1.0 + maxf(0.0, sin(_t * 7.0)) * 0.18 * (1.0 if fmod(_t, 1.2) < 0.6 else 0.4)
	_visual.scale = Vector3.ONE * beat
	_visual.rotation.y = _t * 1.2
	_visual.position.y = 1.1 + sin(_t * 2.0) * 0.08
	if int(_t * 10.0) % 6 == 0 and Engine.get_process_frames() % 6 == 0:
		Vfx.motes(global_position + Vector3.UP * 0.8, 2)


func _physics_process(delta: float) -> void:
	if _arm_time > 0.0:
		_arm_time -= delta
		return
	if _taken:
		return
	for b in get_overlapping_bodies():
		if b is Player and (b as Player).global_position.distance_to(global_position) < 1.8:
			_take(b as Player)
			return


func _take(p: Player) -> void:
	if p.is_dead:
		return
	_taken = true
	var amount := GameState.recover_heart()
	AudioManager.play_event(&"heart_pickup", global_position)
	Vfx.ka_orbs(global_position + Vector3.UP, p, 14)
	Vfx.ring(global_position, 0.3, 3.0, 0.6, Color(1.0, 0.4, 0.3))
	var lv := get_tree().get_first_node_in_group(&"level") as Level
	if lv != null and lv.hud != null:
		lv.hud.notify("Heart reclaimed: +%d Ka" % amount, UIStyle.GOLD)
	SaveSystem.save_game()
	queue_free()
