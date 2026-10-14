class_name Combatant
extends CharacterBody3D
## Shared base of the player and every enemy.
## Scene layout expected:
##   Visual (Node3D)            <- procedural motion layers
##     Rig (CharacterRig)       <- model + AnimationPlayer
##   Health, Poise, Hurtbox, Hitbox, StateMachine
## Local hitstop: while hitstop_left > 0 the state machine, animation and movement
## receive dt = 0, so only this character freezes.

signal died(who: Combatant)
signal damaged(hit: HitInfo)

@export var faction: CombatTypes.Faction = CombatTypes.Faction.ENEMY
@export var gravity: float = 26.0
@export var knockback_decay: float = 9.0
@export var knockback_resist: float = 0.0
## Height of the lock-on marker / aim point.
@export var lock_height: float = 1.2
@export var body_radius: float = 0.4

@onready var visual: Node3D = $Visual
@onready var rig: CharacterRig = $Visual/Rig
@onready var health: HealthComponent = $Health
@onready var poise: PoiseComponent = $Poise
@onready var hurtbox: HurtboxComponent = $Hurtbox
@onready var hitbox: HitboxComponent = $Hitbox
@onready var fsm: StateMachine = $StateMachine

var animator: CharacterAnimator
var motion: ProceduralMotion
var flash_fx: FlashEffect
var hitstop_left: float = 0.0
## True when the last physics tick was frozen by hitstop (for measurements).
var frozen_tick: bool = false
var knockback_velocity: Vector3 = Vector3.ZERO
## Desired horizontal velocity, written by states.
var move_velocity: Vector3 = Vector3.ZERO
var vertical_velocity: float = 0.0
## Multiplies state-machine and animation time (e.g. Ammit phase 2).
var anim_speed: float = 1.0
var is_dead: bool = false
## When false, _move() is skipped (a state moves the body itself, e.g. a leap).
var use_physics_move: bool = true


func _ready() -> void:
	add_to_group(&"combatants")
	add_to_group(&"debug_state")
	hurtbox.entity = self
	hurtbox.faction = faction
	hitbox.attacker = self
	hitbox.faction = faction
	hurtbox.hit_received.connect(_on_hit_received)
	hitbox.hit_landed.connect(_on_hit_landed)
	rig.build(get_clip_table())
	animator = CharacterAnimator.new()
	animator.name = "Animator"
	add_child(animator)
	animator.setup(rig)
	animator.anim_event.connect(_on_anim_event)
	motion = ProceduralMotion.new()
	motion.setup(self, visual)
	flash_fx = FlashEffect.new(rig)
	_add_blob_shadow()
	_combatant_ready()
	fsm.setup(self)


const CRUMBLE_SHADER := preload("res://assets/shaders/crumble.gdshader")
static var _blob_texture: GradientTexture2D

var blob_shadow: Decal


## Soft dark disc projected under the character so it stays grounded where the
## sun casts no shadows (tomb). Character meshes move to render layer 2 so the
## decal (cull mask = layer 1) only darkens the floor.
func _add_blob_shadow() -> void:
	if _blob_texture == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
		g.colors = PackedColorArray([Color(0, 0, 0, 0.75), Color(0, 0, 0, 0.4), Color(0, 0, 0, 0.0)])
		_blob_texture = GradientTexture2D.new()
		_blob_texture.gradient = g
		_blob_texture.fill = GradientTexture2D.FILL_RADIAL
		_blob_texture.fill_from = Vector2(0.5, 0.5)
		_blob_texture.fill_to = Vector2(1.0, 0.5)
		_blob_texture.width = 64
		_blob_texture.height = 64
	blob_shadow = Decal.new()
	blob_shadow.texture_albedo = _blob_texture
	var r := body_radius * 2.8
	blob_shadow.size = Vector3(r, 1.6, r)
	blob_shadow.position = Vector3(0, 0.6, 0)
	blob_shadow.cull_mask = 1
	blob_shadow.albedo_mix = 1.0
	blob_shadow.upper_fade = 0.2
	blob_shadow.lower_fade = 0.4
	add_child(blob_shadow)
	for m in rig.get_meshes():
		m.layers = 2


## Death effect: every mesh switches to a sand material that crumbles from the top down.
func crumble(duration: float = 1.4) -> void:
	var mat := ShaderMaterial.new()
	mat.shader = CRUMBLE_SHADER
	mat.set_shader_parameter(&"base_y", global_position.y - 0.2)
	mat.set_shader_parameter(&"height", lock_height * 1.6 + 0.6)
	for m in rig.get_meshes():
		if is_instance_valid(m):
			m.material_override = mat
			m.material_overlay = null
	if blob_shadow != null:
		create_tween().tween_property(blob_shadow, "modulate:a", 0.0, duration)
	var tw := create_tween()
	tw.tween_method(func(v: float) -> void: mat.set_shader_parameter(&"progress", v), 0.0, 1.0, duration).set_ease(Tween.EASE_IN)


## Subclass hook, called before the state machine starts.
func _combatant_ready() -> void:
	return


## Subclass hook: clip timing table for the rig (logical clip -> timings/events).
func get_clip_table() -> Dictionary:
	return {}


func _physics_process(delta: float) -> void:
	_early_update(delta)
	# Hitstop is rounded to whole ticks (nearest): 55 ms freezes 3 ticks, not 4.
	var frozen := hitstop_left > delta * 0.5
	frozen_tick = frozen
	if frozen:
		hitstop_left -= delta
	else:
		hitstop_left = 0.0
	var dt := 0.0 if frozen else delta
	_pre_update(dt, delta)
	poise.tick(dt)
	fsm.physics_update(dt * anim_speed)
	if not frozen and use_physics_move:
		_move(dt)
	animator.advance(dt * anim_speed)
	motion.update(dt, delta, frozen)
	flash_fx.update(delta)
	_post_update(dt, delta)


## Subclass hook at the very start of the tick, before hitstop is evaluated
## (the player reads its input here).
func _early_update(_real_dt: float) -> void:
	return


## Subclass hooks around the state machine update.
func _pre_update(_dt: float, _real_dt: float) -> void:
	return


func _post_update(_dt: float, _real_dt: float) -> void:
	return


func _move(dt: float) -> void:
	knockback_velocity *= exp(-knockback_decay * dt)
	if knockback_velocity.length_squared() < 0.0025:
		knockback_velocity = Vector3.ZERO
	if is_on_floor() and vertical_velocity <= 0.0:
		vertical_velocity = -1.0
	else:
		vertical_velocity -= gravity * dt
	var h := move_velocity + knockback_velocity
	velocity = Vector3(h.x, vertical_velocity, h.z)
	move_and_slide()
	if is_on_floor() and vertical_velocity < -1.0:
		_on_landed(-vertical_velocity)
		vertical_velocity = -1.0


func _on_landed(impact_speed: float) -> void:
	if impact_speed > 6.0:
		motion.stretch_impulse(-0.2)


func apply_hitstop(duration: float) -> void:
	hitstop_left = maxf(hitstop_left, duration)


# --- facing ----------------------------------------------------------------------

static func yaw_for(dir: Vector3) -> float:
	return atan2(-dir.x, -dir.z)


func forward() -> Vector3:
	var f := -global_basis.z
	f.y = 0.0
	return f.normalized()


func face_instant(dir: Vector3) -> void:
	if Vector2(dir.x, dir.z).length_squared() < 0.0001:
		return
	rotation.y = yaw_for(dir)


func face_toward(dir: Vector3, max_deg_per_s: float, dt: float) -> void:
	if Vector2(dir.x, dir.z).length_squared() < 0.0001:
		return
	var target := yaw_for(dir)
	var diff := angle_difference(rotation.y, target)
	var step := deg_to_rad(max_deg_per_s) * dt
	rotation.y += clampf(diff, -step, step)


## Frame-rate independent turn: exponential approach (sharpness, 1/s) with a minimum
## angular speed so the last degrees never drag. sharpness 0 = constant-rate turn.
func face_smooth(dir: Vector3, sharpness: float, min_deg_per_s: float, dt: float) -> void:
	if Vector2(dir.x, dir.z).length_squared() < 0.0001 or dt <= 0.0:
		return
	var diff := angle_difference(rotation.y, yaw_for(dir))
	var step := maxf(absf(diff) * (1.0 - exp(-sharpness * dt)), deg_to_rad(min_deg_per_s) * dt)
	rotation.y += clampf(diff, -step, step)


func direction_to_node(n: Node3D) -> Vector3:
	var d := n.global_position - global_position
	d.y = 0.0
	return d.normalized() if d.length_squared() > 0.0001 else forward()


func flat_distance_to(p: Vector3) -> float:
	return Vector2(p.x - global_position.x, p.z - global_position.z).length()


func aim_point() -> Vector3:
	return global_position + Vector3.UP * lock_height


func is_targetable() -> bool:
	return not is_dead and hurtbox.monitorable


func teleport_to(pos: Vector3, yaw: float) -> void:
	global_position = pos
	rotation.y = yaw
	move_velocity = Vector3.ZERO
	knockback_velocity = Vector3.ZERO
	vertical_velocity = 0.0
	velocity = Vector3.ZERO
	motion.reset()
	reset_physics_interpolation()


# --- combat -----------------------------------------------------------------------

func _on_hit_received(hit: HitInfo) -> void:
	if is_dead:
		return
	hit.damage = _modify_incoming_damage(hit)
	health.damage(hit.damage)
	if hit.is_dot:
		flash_fx.flash(Color(0.5, 1.0, 0.3), 0.15, 0.5)
		if health.dead:
			hit.killed = true
			is_dead = true
			_on_death(hit)
			died.emit(self)
		damaged.emit(hit)
		return
	apply_knockback(hit.direction, hit.knockback)
	flash_fx.flash(Color(1.0, 0.95, 0.85), 0.16 if hit.is_heavy else 0.12)
	motion.recoil(hit.direction, 0.6 if hit.is_heavy else 0.35)
	if hit.is_projectile or hit.attacker == null:
		HitStop.freeze([self], hit.hitstop)
	else:
		HitStop.freeze([self, hit.attacker], hit.hitstop)
	if health.dead:
		hit.killed = true
		is_dead = true
		_on_death(hit)
		died.emit(self)
	else:
		_react_to_hit(hit)
	damaged.emit(hit)


func apply_knockback(dir: Vector3, strength: float) -> void:
	var d := dir
	d.y = 0.0
	if d.length_squared() < 0.0001:
		return
	knockback_velocity += d.normalized() * strength * (1.0 - knockback_resist) * 2.2


## Subclass: damage modifiers (stagger window multipliers, armour ...).
func _modify_incoming_damage(hit: HitInfo) -> float:
	return hit.damage


## Subclass: flinch / stagger / interrupt logic.
func _react_to_hit(_hit: HitInfo) -> void:
	return


## Subclass: death handling (state change, drops ...).
func _on_death(_hit: HitInfo) -> void:
	return


## Called when our hitbox lands a hit on something.
func _on_hit_landed(_target: Node3D, _hit: HitInfo) -> void:
	return


func _on_anim_event(event: StringName, tag: StringName) -> void:
	match event:
		&"footstep":
			_footstep(&"")
		&"footstep_r":
			_footstep(&"r")
		&"footstep_l":
			_footstep(&"l")
	fsm.forward_anim_event(event, tag)


## side: &"r" / &"l" when the clip says which foot landed, else &"".
func _footstep(_side: StringName) -> void:
	return


func get_debug_state() -> String:
	return "%s: %s  hp %d" % [name, fsm.current_name(), int(health.current)]
