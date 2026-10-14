class_name CharacterAnimator
extends Node
## Builds and drives an AnimationTree for a CharacterRig:
##   root = AnimationNodeStateMachine
##     "locomotion" = BlendSpace1D (idle -> walk -> run)
##     one state per logical clip in AnimationMap.states (attacks, dodge, hit, death ...)
## The tree is advanced manually from the owner's physics step so local hitstop can
## freeze it, and method tracks fire immediately (deterministic animation events).

signal anim_event(event: StringName, tag: StringName)

const LOCOMOTION := &"locomotion"

var rig: CharacterRig
var tree: AnimationTree
var playback: AnimationNodeStateMachinePlayback
var map: AnimationMap
var current: StringName = LOCOMOTION
var speed_scale: float = 1.0
var _states: Array[StringName] = []


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
	var loco := AnimationNodeBlendSpace1D.new()
	loco.min_space = 0.0
	loco.max_space = 1.0
	loco.snap = 0.01
	for logical: StringName in map.locomotion:
		var clip := map.resolve(logical, player)
		if clip == &"":
			continue
		var n := AnimationNodeAnimation.new()
		n.animation = clip
		loco.add_blend_point(n, float(map.locomotion[logical]))
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
	else:
		playback.travel(logical)
	current = logical


func play_locomotion() -> void:
	play(LOCOMOTION, false)


func set_locomotion_blend(value: float) -> void:
	tree.set(&"parameters/locomotion/blend_position", clampf(value, 0.0, 1.0))


func advance(dt: float) -> void:
	if tree != null:
		tree.advance(dt * speed_scale)


func current_position() -> float:
	return playback.get_current_play_position()


func _on_rig_event(event: StringName, tag: StringName) -> void:
	# Events from clips that are only fading out are ignored by the states via the tag.
	anim_event.emit(event, tag)
