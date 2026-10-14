class_name State
extends Node
## Base state. Subclasses override the virtual methods they need.

var machine: StateMachine
## The character that owns the state machine.
var actor: Node
## Time spent in this state (in the actor's local time, i.e. frozen by hitstop).
var time_in_state: float = 0.0


## Called once after the machine assigned `machine` and `actor`.
func on_setup() -> void:
	return


## Called on entering. `msg` carries optional parameters from the transition.
func enter(_msg: Dictionary) -> void:
	return


func exit() -> void:
	return


## Called every physics frame with the actor's local delta (0 during hitstop).
func physics_update(_dt: float) -> void:
	return


## Animation events forwarded from the rig (hitbox_on, hitbox_off, footstep...).
func on_anim_event(_event: StringName, _tag: StringName) -> void:
	return


## Return false to refuse an incoming hit reaction (e.g. hyper armour).
func can_be_interrupted() -> bool:
	return true


func transition(to: StringName, msg: Dictionary = {}) -> void:
	machine.transition_to(to, msg)
