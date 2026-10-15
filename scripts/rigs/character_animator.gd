class_name CharacterAnimator
extends Node
## Builds and drives an AnimationTree for a CharacterRig:
##   root = AnimationNodeStateMachine
##     "locomotion" = BlendTree: BlendSpace1D (idle -> walk -> run, synced) -> TimeScale
##     one state per logical clip in AnimationMap.states (attacks, dodge, hit, death ...)
## Crossfades: combat_xfade into action states, recover_xfade back into locomotion.
## Speed-matched locomotion: when the walk / run clips carry a "stride" (metres per
## cycle, clip metadata or AnimationMap.strides), the cycle is played at the rate that
## matches the real speed, so planted feet do not slide.
## The tree is advanced manually from the owner's physics step so local hitstop can
## freeze it, and method tracks fire immediately (deterministic animation events).

signal anim_event(event: StringName, tag: StringName)

const LOCOMOTION := &"locomotion"
const P_BLEND := &"parameters/locomotion/space/blend_position"
const P_SCALE := &"parameters/locomotion/speed/scale"

var rig: CharacterRig
var tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var map: AnimationMap
var current: StringName = LOCOMOTION
var speed_scale: float = 1.0
## Extra playback rate of the current action clip (e.g. a dodge retimed by the preset).
var action_speed: float = 1.0
## The state machine applies a travel() two advances later (path, then fade start) and a
## start() one advance later. When true, play() primes the tree with zero-time advances so
## the new clip starts in the tick it was requested (the hero; enemies keep the old timing).
var prime_transitions: bool = false
var _states: Array[StringName] = []
## Moving locomotion points: [[blend position, stride (m per cycle), clip length], ...]
var _gait: Array = []


func setup(p_rig: CharacterRig) -> void:
	rig = p_rig
	map = rig.anim_map
	var player := rig.get_animation_player()
	tree = AnimationTree.new()
	tree.name = "AnimationTree"
	player.get_parent().add_child(tree)
	tree.anim_player = tree.get_path_to(player)
	tree.root_node = tree.get_path_to(player.get_node(player.root_node))
	tree.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_MANUAL
	tree.callback_mode_method = AnimationMixer.ANIMATION_CALLBACK_MODE_METHOD_IMMEDIATE
	tree.deterministic = true
	tree.tree_root = _build_state_machine(player)
	tree.active = true
	playback = tree.get(&"parameters/playback") as AnimationNodeStateMachinePlayback
	playback.start(LOCOMOTION)
	rig.animation_event.connect(_on_rig_event)
	tree.advance(0.0)


func _build_state_machine(player: AnimationPlayer) -> AnimationNodeStateMachine:
	var sm := AnimationNodeStateMachine.new()
	var space := AnimationNodeBlendSpace1D.new()
	space.min_space = 0.0
	space.max_space = 1.0
	space.snap = 0.01
	# All cycles advance together, so walk and run (same length) stay in phase.
	space.sync = true
	_gait.clear()
	for logical: StringName in map.locomotion:
		var clip := map.resolve(logical, player)
		if clip == &"":
			continue
		var n := AnimationNodeAnimation.new()
		n.animation = clip
		var pos := float(map.locomotion[logical])
		space.add_blend_point(n, pos, -1, logical)
		var anim := player.get_animation(clip)
		var stride := float(map.strides.get(logical, anim.get_meta(&"stride", 0.0)))
		if pos > 0.0 and stride > 0.0:
			_gait.append([pos, stride, anim.length])
	_gait.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	var loco := AnimationNodeBlendTree.new()
	loco.add_node(&"space", space)
	loco.add_node(&"speed", AnimationNodeTimeScale.new())
	loco.connect_node(&"speed", 0, &"space")
	loco.connect_node(&"output", 0, &"speed")
	sm.add_node(LOCOMOTION, loco)
	_states = [LOCOMOTION]
	for logical: StringName in map.states:
		var clip := map.resolve(logical, player)
		if clip == &"":
			push_warning("CharacterAnimator: no clip for '%s' on %s" % [logical, rig.owner.name if rig.owner else rig.name])
			continue
		var n := AnimationNodeAnimation.new()
		n.animation = clip
		sm.add_node(logical, n)
		_states.append(logical)
	for a: StringName in _states:
		for b: StringName in _states:
			if a == b:
				continue
			var trans := AnimationNodeStateMachineTransition.new()
			trans.xfade_time = map.xfade
			# Restart the target clip even if it was the previous state (chains, re-dodges).
			trans.reset = true
			trans.switch_mode = AnimationNodeStateMachineTransition.SWITCH_MODE_IMMEDIATE
			trans.advance_mode = AnimationNodeStateMachineTransition.ADVANCE_MODE_ENABLED
			sm.add_transition(a, b, trans)
	return sm


func has_state(logical: StringName) -> bool:
	return _states.has(logical)


## Plays a logical state. `restart` replays it even if already current.
func play(logical: StringName, restart: bool = true) -> void:
	if not has_state(logical):
		logical = LOCOMOTION
	if logical == current and not restart:
		return
	if logical == current:
		playback.start(logical, true)
		if prime_transitions:
			tree.advance(0.0)
	else:
		playback.travel(logical)
		if prime_transitions:
			tree.advance(0.0)
			tree.advance(0.0)
	current = logical


func play_locomotion() -> void:
	play(LOCOMOTION, false)


## Crossfade times: into action states (combat) and back into locomotion (recover).
func set_xfades(combat: float, recover: float) -> void:
	var sm := tree.tree_root as AnimationNodeStateMachine
	for i in sm.get_transition_count():
		sm.get_transition(i).xfade_time = recover if sm.get_transition_to(i) == LOCOMOTION else combat


func set_locomotion_blend(value: float) -> void:
	tree.set(P_BLEND, clampf(value, 0.0, 1.0))


func get_locomotion_blend() -> float:
	return float(tree.get(P_BLEND))


## Drives the locomotion blend from the real speed; with `match_speed` the cycle rate
## follows the speed so the feet stay planted (needs stride data, see _gait).
func set_locomotion(speed: float, run_speed: float, match_speed: bool) -> void:
	var b := clampf(speed / maxf(run_speed, 0.01), 0.0, 1.0)
	tree.set(P_BLEND, b)
	var scale := 1.0
	if match_speed and not _gait.is_empty():
		scale = _cycle_scale(speed, b, run_speed)
	tree.set(P_SCALE, scale)


## Playback rate that makes the blended stride cover `speed`. Below the first moving
## point (idle <-> walk) the cadence stays the walk's and fades to 1 at a standstill.
func _cycle_scale(speed: float, b: float, run_speed: float) -> float:
	var first: Array = _gait[0]
	var b0 := float(first[0])
	if b <= b0:
		var walk_scale := (b0 * run_speed) / float(first[1]) * float(first[2])
		return lerpf(1.0, walk_scale, b / b0)
	var stride := float(first[1])
	var length := float(first[2])
	for i in range(1, _gait.size()):
		var lo: Array = _gait[i - 1]
		var hi: Array = _gait[i]
		if b <= float(hi[0]) or i == _gait.size() - 1:
			var u := clampf((b - float(lo[0])) / maxf(float(hi[0]) - float(lo[0]), 0.001), 0.0, 1.0)
			stride = lerpf(float(lo[1]), float(hi[1]), u)
			length = lerpf(float(lo[2]), float(hi[2]), u)
			break
	return clampf(speed / stride * length, 0.2, 4.0)


## Length (s) of the clip behind a logical state, 0 if unknown.
func clip_length(logical: StringName) -> float:
	var ap := rig.get_animation_player()
	var clip := map.resolve(logical, ap)
	return ap.get_animation(clip).length if clip != &"" else 0.0


func set_action_speed(value: float) -> void:
	action_speed = value


func advance(dt: float) -> void:
	if tree != null:
		tree.advance(dt * speed_scale * (action_speed if current != LOCOMOTION else 1.0))


func current_position() -> float:
	return playback.get_current_play_position()


func _on_rig_event(event: StringName, tag: StringName) -> void:
	# Events from clips that are only fading out are ignored by the states via the tag.
	anim_event.emit(event, tag)
