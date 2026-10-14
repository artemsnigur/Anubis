class_name StateMachine
extends Node
## Finite state machine whose states are child State nodes.

signal state_changed(from: StringName, to: StringName)

@export var initial_state: StringName = &""
var current: State
var states: Dictionary = {}
var actor: Node
var previous_name: StringName = &""


func setup(p_actor: Node) -> void:
	actor = p_actor
	for c in get_children():
		if c is State:
			var s := c as State
			s.machine = self
			s.actor = p_actor
			states[StringName(s.name)] = s
	if initial_state != &"" and states.has(initial_state):
		current = states[initial_state]
		current.time_in_state = 0.0
		current.enter({})


func transition_to(to: StringName, msg: Dictionary = {}) -> void:
	if not states.has(to):
		push_warning("StateMachine: unknown state '%s' on %s" % [to, str(actor.name) if actor else "?"])
		return
	var from_name: StringName = &""
	if current != null:
		from_name = StringName(current.name)
		current.exit()
	previous_name = from_name
	current = states[to]
	current.time_in_state = 0.0
	current.enter(msg)
	state_changed.emit(from_name, to)


func physics_update(dt: float) -> void:
	if current == null:
		return
	current.time_in_state += dt
	current.physics_update(dt)


func forward_anim_event(event: StringName, tag: StringName) -> void:
	if current != null:
		current.on_anim_event(event, tag)


func current_name() -> StringName:
	return StringName(current.name) if current != null else &""


func is_in(state_name: StringName) -> bool:
	return current != null and StringName(current.name) == state_name
