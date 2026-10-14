class_name ModelRig
extends CharacterRig
## Rig for an imported, skinned model (glTF / FBX from Mixamo, Quaternius, KayKit ...).
##
## Import the model with Skeleton3D > Retarget > Bone Map = new BoneMap using
## SkeletonProfileHumanoid: bones are then named Hips, Spine, Chest, Head, RightHand ...
## and animations from any humanoid pack retargeted to the same profile play on it.
##
## Swap a character: replace its Visual/Rig node with a ModelRig, set `model_scene`
## and an AnimationMap whose `clips` map logical names (idle, run, light_1 ...) to the
## clip names inside the model. Gameplay code is untouched: hitbox/footstep/heal events
## are injected as method tracks at the AttackData / PlayerStats timings.

## The imported scene (.glb / .fbx / .tscn) containing a Skeleton3D and an AnimationPlayer.
@export var model_scene: PackedScene
## glTF characters face +Z; gameplay faces -Z.
@export var model_rotation_y_deg: float = 180.0
@export var model_scale: float = 1.0
## socket name -> humanoid bone name.
@export var socket_bones: Dictionary = {
	&"weapon_r": &"RightHand", &"hand_l": &"LeftHand", &"head": &"Head", &"chest": &"Chest",
	&"weapon_tip": &"RightHand", &"mouth": &"Head", &"grab": &"Chest",
}
## Optional weapon scene attached to the weapon_r socket.
@export var weapon_scene: PackedScene
## Trail points relative to the weapon socket (blade base / tip).
@export var trail_base_offset: Vector3 = Vector3(0, 0.15, 0)
@export var trail_tip_offset: Vector3 = Vector3(0, 0.85, 0)

var model: Node3D
var skeleton: Skeleton3D


func build(clips: Dictionary) -> void:
	if model_scene == null:
		push_warning("ModelRig: no model_scene set")
		return
	model = model_scene.instantiate() as Node3D
	model.rotation_degrees.y = model_rotation_y_deg
	model.scale = Vector3.ONE * model_scale
	add_child(model)
	anim_player = _find(model, "AnimationPlayer") as AnimationPlayer
	skeleton = _find(model, "Skeleton3D") as Skeleton3D
	if anim_player == null:
		anim_player = AnimationPlayer.new()
		add_child(anim_player)
	_attach_sockets()
	_prepare_animations(clips)


func _find(n: Node, cls: String) -> Node:
	if n.is_class(cls):
		return n
	for c in n.get_children():
		var r := _find(c, cls)
		if r != null:
			return r
	return null


func _attach_sockets() -> void:
	for socket: StringName in socket_bones:
		var target: Node3D = self
		if skeleton != null:
			var bone := String(socket_bones[socket])
			if skeleton.find_bone(bone) >= 0:
				var att := BoneAttachment3D.new()
				att.bone_name = bone
				skeleton.add_child(att)
				target = att
		var s := Node3D.new()
		s.name = String(socket)
		target.add_child(s)
		sockets[socket] = s
	if weapon_scene != null:
		var w := weapon_scene.instantiate() as Node3D
		(sockets[&"weapon_r"] as Node3D).add_child(w)
	var base := Node3D.new()
	base.position = trail_base_offset
	(sockets[&"weapon_r"] as Node3D).add_child(base)
	sockets[&"trail_base"] = base
	var tip := Node3D.new()
	tip.position = trail_tip_offset
	(sockets[&"weapon_r"] as Node3D).add_child(tip)
	sockets[&"trail_tip"] = tip


## Duplicates the imported libraries (imported resources are shared/read-only),
## sets loop modes and injects gameplay events derived from the timing table.
func _prepare_animations(clips: Dictionary) -> void:
	for lib_name: StringName in anim_player.get_animation_library_list():
		var lib := anim_player.get_animation_library(lib_name).duplicate(true) as AnimationLibrary
		anim_player.remove_animation_library(lib_name)
		anim_player.add_animation_library(lib_name, lib)
	var root := anim_player.get_node(anim_player.root_node)
	var logical_names: Array = []
	logical_names.append_array(clips.keys())
	if anim_map != null:
		for l: StringName in anim_map.locomotion:
			if not logical_names.has(l):
				logical_names.append(l)
		for l: StringName in anim_map.states:
			if not logical_names.has(l):
				logical_names.append(l)
	# Per-instance map copy: logical actions sharing one imported clip get their own
	# copy so each carries events tagged with its own logical name.
	if anim_map != null:
		anim_map = anim_map.duplicate(true) as AnimationMap
	var used: Dictionary = {}
	var own_lib: AnimationLibrary = null
	for logical: StringName in logical_names:
		var clip := anim_map.resolve(logical, anim_player) if anim_map != null else logical
		if clip == &"":
			continue
		var anim := anim_player.get_animation(clip)
		if used.has(clip):
			if own_lib == null:
				own_lib = AnimationLibrary.new()
				anim_player.add_animation_library(&"rig", own_lib)
			anim = anim.duplicate(true) as Animation
			own_lib.add_animation(logical, anim)
			anim_map.clips[logical] = StringName("rig/" + String(logical)) if anim_map.library == &"" else logical
		used[clip] = true
		if anim_map != null and anim_map.looping.has(logical):
			anim.loop_mode = Animation.LOOP_LINEAR
		var events := events_for(logical, clips.get(logical, {}), anim.length)
		CharacterRig.inject_events(anim, events, logical, root, self)


## Gameplay events for a logical clip, from its timing entry.
static func events_for(logical: StringName, t: Dictionary, length: float) -> Array:
	var ev: Array = []
	if t.has("windup"):
		var w := float(t["windup"])
		var a := float(t.get("active", 0.1))
		if t.has("lead"):
			ev.append([maxf(w - float(t["lead"]), 0.017), &"telegraph"])
		ev.append([maxf(w * 0.4, 0.017), &"swing"])
		ev.append([maxf(w, 0.02), &"hitbox_on"])
		ev.append([w + a, &"hitbox_off"])
		if logical == &"cast":
			ev.append([maxf(w, 0.02), &"cast_fire"])
	match logical:
		&"walk", &"run":
			ev.append([0.02, &"footstep"])
			ev.append([length * 0.5, &"footstep"])
		&"heal":
			ev.append([float(t.get("apply", length * 0.6)), &"heal_apply"])
		&"dodge":
			ev.append([0.017, &"dodge_start"])
		&"death":
			ev.append([length * 0.7, &"body_fall"])
		&"interact":
			ev.append([length * 0.6, &"interact_point"])
	return ev
