class_name HeroAlive
extends RefCounted
## "Alive" layers of the hero that act on rig bones after the AnimationTree has posed
## them (Player._post_update, every physics tick):
##   * breathing (chest / neck / shoulders), faster and deeper after exertion,
##   * head / neck / chest turn toward the nearest enemy, else the aim direction,
##   * spring-driven secondary motion: kilt panel, wig lappets, linen sash, weapon sway
##     (pendulums swinging toward "apparent gravity" = gravity - acceleration - drag),
##   * dust: footsteps at the planted foot, skid on pivots and hard stops, run start.
## Additive offsets are removed again before re-applying when the animation did not
## rewrite the bone (e.g. advance(0) during hitstop), so nothing accumulates.
## Works on PlaceholderRig bones; other rigs only get the dust.

const LOOK_RANGE := 9.0
## [bone, stiffness, damping, x limits (rad, back / forward), drag]
const SPRINGS := [
	["KiltFlap", 120.0, 7.0, Vector2(-0.3, 1.0), 0.6],
	["LappetL", 160.0, 6.0, Vector2(-0.6, 0.6), 0.35],
	["LappetR", 160.0, 6.0, Vector2(-0.6, 0.6), 0.35],
	["SashL1", 70.0, 5.0, Vector2(-0.2, 1.3), 1.0],
	["SashL2", 90.0, 4.0, Vector2(-0.8, 0.8), 1.0],
	["SashR1", 66.0, 5.0, Vector2(-0.2, 1.3), 1.0],
	["SashR2", 86.0, 4.0, Vector2(-0.8, 0.8), 1.0],
]

var player: Player
var rig: PlaceholderRig
## 0..1, raised by attacks / dodges, decays over a few seconds (heavier breathing).
var exertion: float = 0.0
var _breath_t: float = 0.0
var _look: float = 0.0
var _springs: Array[Dictionary] = []
var _weapon: Node3D
var _weapon_rest: Basis
var _weapon_prev: Vector3
var _weapon_vel: Vector3 = Vector3.ZERO
var _weapon_off: Vector2 = Vector2.ZERO
var _weapon_off_vel: Vector2 = Vector2.ZERO
var _offsets: Dictionary = {}    # bone -> [written basis, applied offset]


func setup(p_player: Player) -> void:
	player = p_player
	rig = player.rig as PlaceholderRig
	if rig == null:
		return
	for spec: Array in SPRINGS:
		var n := rig.bones.get(spec[0]) as Node3D
		if n == null:
			continue
		_springs.append({"node": n, "k": spec[1], "c": spec[2], "lim": spec[3], "drag": spec[4],
			"rest": n.basis, "prev": n.global_position, "vel": Vector3.ZERO, "ang": Vector2.ZERO, "ang_vel": Vector2.ZERO})
	_weapon = rig.get_socket(&"weapon_r")
	if _weapon == rig:
		_weapon = null
	else:
		_weapon_rest = _weapon.basis
		_weapon_prev = _weapon.global_position


func reset() -> void:
	for s in _springs:
		var n: Node3D = s["node"]
		n.basis = s["rest"]
		s["prev"] = n.global_position
		s["vel"] = Vector3.ZERO
		s["ang"] = Vector2.ZERO
		s["ang_vel"] = Vector2.ZERO
	_weapon_off = Vector2.ZERO
	_weapon_off_vel = Vector2.ZERO
	if _weapon != null:
		_weapon.basis = _weapon_rest
		_weapon_prev = _weapon.global_position
		_weapon_vel = Vector3.ZERO


func add_exertion(amount: float) -> void:
	exertion = clampf(exertion + amount, 0.0, 1.0)


## dt = local tick (0 while frozen by hitstop), real_dt = tick length.
func update(dt: float, real_dt: float) -> void:
	if rig == null:
		return
	var f := player.feel
	exertion = maxf(exertion - real_dt * 0.12, 0.0)
	var add: Dictionary = {}
	_breathe(f, dt, add)
	_look_at(f, real_dt, add)
	_apply_offsets(add)
	if dt > 0.0:
		_secondary(f, dt)


func _breathe(f: FeelPreset, dt: float, add: Dictionary) -> void:
	if f.breathing <= 0.0:
		return
	var speed_k := clampf(player.move_velocity.length() / player.stats.run_speed, 0.0, 1.0)
	_breath_t += dt * lerpf(0.3, 0.95, exertion) * TAU
	var amp := f.breathing * lerpf(1.0, 2.4, exertion) * (1.0 - 0.6 * speed_k)
	var b := sin(_breath_t)
	_add(add, "Chest", Vector3(deg_to_rad(-2.2 * amp * b), 0.0, 0.0))
	_add(add, "Neck", Vector3(deg_to_rad(1.2 * amp * b), 0.0, 0.0))
	_add(add, "ArmR", Vector3(0.0, 0.0, deg_to_rad(-1.4 * amp * b)))
	_add(add, "ArmL", Vector3(0.0, 0.0, deg_to_rad(1.4 * amp * b)))


func _look_at(f: FeelPreset, sdt: float, add: Dictionary) -> void:
	var weight := f.look_at
	var st := player.fsm.current_name()
	if st == &"Dodge" or st == &"Dead" or st == &"Grabbed" or st == &"Busy" or st == &"Hurt":
		weight = 0.0
	elif st == &"Attack" or st == &"Heavy" or st == &"Cast":
		weight *= 0.4
	var target := 0.0
	if weight > 0.0:
		var dir := _look_direction()
		if dir != Vector3.ZERO:
			target = clampf(angle_difference(player.rotation.y, Combatant.yaw_for(dir)), deg_to_rad(-75.0), deg_to_rad(75.0)) * weight
	_look = lerpf(_look, target, 1.0 - exp(-9.0 * sdt))
	if absf(_look) < 0.0005:
		return
	_add(add, "Chest", Vector3(0.0, _look * 0.25, 0.0))
	_add(add, "Neck", Vector3(0.0, _look * 0.3, 0.0))
	_add(add, "Head", Vector3(0.0, _look * 0.45, 0.0))


func _look_direction() -> Vector3:
	var best: Combatant = player.lock_on.target
	if best == null:
		var bd := LOOK_RANGE
		for n in player.get_tree().get_nodes_in_group(&"enemies"):
			var e := n as Combatant
			if e == null or not e.is_targetable():
				continue
			var d := e.global_position.distance_to(player.global_position)
			if d < bd and absf(e.global_position.y - player.global_position.y) < 2.5:
				bd = d
				best = e
	if best != null:
		return player.direction_to_node(best)
	return player.input.aim_direction(player.global_position)


func _add(add: Dictionary, bone: String, euler: Vector3) -> void:
	add[bone] = (add.get(bone, Vector3.ZERO) as Vector3) + euler


## Applies this tick's additive rotations. If a bone still holds what we wrote last tick
## (the animation did not pose it again), the old offset is taken out first.
func _apply_offsets(add: Dictionary) -> void:
	for bone: String in _offsets.keys():
		var n := rig.bones.get(bone) as Node3D
		var rec: Array = _offsets[bone]
		if n != null and n.basis.is_equal_approx(rec[0] as Basis):
			n.basis = n.basis * (rec[1] as Basis).inverse()
	_offsets.clear()
	for bone: String in add:
		var n := rig.bones.get(bone) as Node3D
		if n == null:
			continue
		var off := Basis.from_euler(add[bone] as Vector3)
		n.basis = n.basis * off
		_offsets[bone] = [n.basis, off]


func _secondary(f: FeelPreset, dt: float) -> void:
	var amount := f.secondary_motion
	for s in _springs:
		var n: Node3D = s["node"]
		var parent := n.get_parent() as Node3D
		var pos := n.global_position
		var vel := (pos - (s["prev"] as Vector3)) / dt
		var acc := (vel - (s["vel"] as Vector3)) / dt
		s["prev"] = pos
		s["vel"] = vel
		var inv := parent.global_basis.orthonormalized().inverse()
		var g := inv * (Vector3.DOWN * 9.8 - acc.limit_length(60.0) * 0.6 - vel * float(s["drag"]) * 2.2)
		var lim: Vector2 = s["lim"]
		var target := Vector2(clampf(atan2(-g.z, -g.y), lim.x, lim.y), clampf(atan2(g.x, -g.y), -0.7, 0.7)) * amount
		var ang: Vector2 = s["ang"]
		var av: Vector2 = s["ang_vel"]
		av += ((target - ang) * float(s["k"]) - av * float(s["c"])) * dt
		ang += av * dt
		s["ang"] = ang
		s["ang_vel"] = av
		n.basis = (s["rest"] as Basis) * Basis.from_euler(Vector3(ang.x, 0.0, ang.y))
	# Weapon sway: the blade lags behind sudden hand motion and settles.
	if _weapon != null:
		var hand := _weapon.get_parent() as Node3D
		var p := _weapon.global_position
		var v := (p - _weapon_prev) / dt
		_weapon_prev = p
		var a := hand.global_basis.orthonormalized().inverse() * ((v - _weapon_vel) / dt)
		_weapon_vel = v
		_weapon_off_vel += (Vector2(a.z, -a.x).limit_length(80.0) * 0.004 * amount - _weapon_off * 260.0 - _weapon_off_vel * 18.0) * dt
		_weapon_off += _weapon_off_vel * dt
		_weapon_off = _weapon_off.limit_length(0.35)
		_weapon.basis = _weapon_rest * Basis.from_euler(Vector3(_weapon_off.x, 0.0, _weapon_off.y))


# --- dust ---------------------------------------------------------------------------------

## Pivot / hard stop: lean back, dust from the planted feet, a scuff.
func skid(strength: float, old_dir: Vector3) -> void:
	if not player.feel.skid_fx:
		return
	player.motion.skid(strength)
	Vfx.dust(player.global_position + old_dir * 0.35, int(4 + 6 * strength), 0.7 + 0.5 * strength)
	AudioManager.play_event(&"footstep_sand" if player.global_position.y > -1.0 else &"footstep_stone", player.global_position, 2.0 + 2.0 * strength)


func run_start(dir: Vector3) -> void:
	if not player.feel.skid_fx:
		return
	Vfx.dust(player.global_position - dir * 0.3, 3, 0.6)
	player.motion.anticipate(0.35)
