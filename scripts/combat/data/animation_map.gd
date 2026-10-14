class_name AnimationMap
extends Resource
## Single table that maps logical animation names used by gameplay code
## to the actual clip names inside the character's AnimationPlayer.
## Swap a model -> edit this table (and the rig), gameplay code stays untouched.

## Library prefix inside the AnimationPlayer ("" = default library).
@export var library: StringName = &""
## logical name -> clip name. Logical names missing here map to themselves.
@export var clips: Dictionary = {}
## logical name -> other logical name used when the clip does not exist.
@export var fallbacks: Dictionary = {}
## Locomotion blend space: logical name -> blend position (speed / run speed).
@export var locomotion: Dictionary = {&"idle": 0.0, &"walk": 0.45, &"run": 1.0}
## Logical names of one-shot states built into the AnimationTree state machine.
@export var states: Array[StringName] = []
## Logical names that loop.
@export var looping: Array[StringName] = [&"idle", &"walk", &"run"]
## Crossfade time between states.
@export var xfade: float = 0.06


func clip_name(logical: StringName) -> StringName:
	var clip: StringName = clips.get(logical, logical)
	if library == &"":
		return clip
	return StringName("%s/%s" % [library, clip])


## Resolves a logical name to an existing clip, following fallbacks.
func resolve(logical: StringName, player: AnimationPlayer) -> StringName:
	var current := logical
	for _i in 4:
		var clip := clip_name(current)
		if player.has_animation(clip):
			return clip
		if not fallbacks.has(current):
			break
		current = fallbacks[current]
	return &""
