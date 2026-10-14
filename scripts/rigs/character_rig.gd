class_name CharacterRig
extends Node3D
## Base of every character visual. Owns the AnimationPlayer, exposes sockets
## (weapon, eyes, mouth ...) and relays animation method-track events.
##
## Two implementations:
##  * PlaceholderRig subclasses - stylised primitives + generated clips (default).
##  * ModelRig - any imported .glb/.fbx (Mixamo, Quaternius, KayKit ...) retargeted
##    to SkeletonProfileHumanoid; events are injected into its clips from AttackData.

signal animation_event(event: StringName, tag: StringName)

@export var anim_map: AnimationMap
var anim_player: AnimationPlayer
var sockets: Dictionary = {}


## Builds model + animations. `clips` = logical clip -> {"length": float, "events": [[t, event], ...], ...}
func build(_clips: Dictionary) -> void:
	return


func get_animation_player() -> AnimationPlayer:
	return anim_player


func get_socket(socket_name: StringName) -> Node3D:
	return sockets.get(socket_name, self) as Node3D


func has_socket(socket_name: StringName) -> bool:
	return sockets.has(socket_name)


## Target of the generated/injected method tracks.
func anim_event(event: StringName, tag: StringName) -> void:
	animation_event.emit(event, tag)


func get_meshes() -> Array[GeometryInstance3D]:
	var out: Array[GeometryInstance3D] = []
	_collect_meshes(self, out)
	return out


func _collect_meshes(n: Node, out: Array[GeometryInstance3D]) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			out.append(c as GeometryInstance3D)
		_collect_meshes(c, out)


## Adds a method track calling anim_event(event, tag) at the given times.
## `track_root` is the node the AnimationPlayer resolves paths from.
static func inject_events(anim: Animation, events: Array, tag: StringName, track_root: Node, rig: Node) -> void:
	if events.is_empty():
		return
	var path := track_root.get_path_to(rig)
	var idx := anim.add_track(Animation.TYPE_METHOD)
	anim.track_set_path(idx, path)
	for e: Array in events:
		var t := clampf(float(e[0]), 0.0, anim.length)
		anim.track_insert_key(idx, t, {"method": &"anim_event", "args": [StringName(e[1]), tag]})
