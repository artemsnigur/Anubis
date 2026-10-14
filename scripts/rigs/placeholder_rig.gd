class_name PlaceholderRig
extends CharacterRig
## A "skeleton" of Node3D pivots with primitive meshes, animated by clips generated
## in code (AnimBuilder). Subclasses implement _build_body() and _build_clips().
## Generated libraries are cached per rig script + timing table, so many enemies
## of the same type share one AnimationLibrary.

static var _library_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}

var bones: Dictionary = {}       # name -> Node3D
var _rest_pos: Dictionary = {}   # name -> Vector3
var _paths: Dictionary = {}      # name -> NodePath (relative to rig)
var clip_table: Dictionary = {}


func build(clips: Dictionary) -> void:
	clip_table = clips
	_build_body()
	anim_player = AnimationPlayer.new()
	anim_player.name = "AnimationPlayer"
	add_child(anim_player)
	var key := "%s|%s" % [get_script().resource_path, str(clips.hash())]
	var lib: AnimationLibrary = _library_cache.get(key)
	if lib == null:
		lib = AnimationLibrary.new()
		_build_clips(lib)
		_library_cache[key] = lib
	anim_player.add_animation_library(&"", lib)


## Subclass: create bones and meshes.
func _build_body() -> void:
	return


## Subclass: add clips to the library using AnimBuilder.
func _build_clips(_lib: AnimationLibrary) -> void:
	return


# --- skeleton helpers ---------------------------------------------------------

func add_bone(bone_name: String, parent_name: String, pos: Vector3) -> Node3D:
	var b := Node3D.new()
	b.name = bone_name
	b.position = pos
	var parent: Node3D = self if parent_name == "" else bones[parent_name]
	parent.add_child(b)
	bones[bone_name] = b
	_rest_pos[bone_name] = pos
	_paths[bone_name] = _relative_path(b)
	return b


func _relative_path(b: Node) -> NodePath:
	var parts: PackedStringArray = []
	var n: Node = b
	while n != null and n != self:
		parts.insert(0, String(n.name))
		n = n.get_parent()
	return NodePath("/".join(parts))


func bone_path(bone_name: String) -> NodePath:
	return _paths.get(bone_name, NodePath(bone_name))


func rest_position(bone_name: String) -> Vector3:
	return _rest_pos.get(bone_name, Vector3.ZERO)


func add_socket(socket_name: StringName, bone_name: String, pos: Vector3, rot_deg: Vector3 = Vector3.ZERO) -> Node3D:
	var s := Node3D.new()
	s.name = String(socket_name)
	s.position = pos
	s.rotation_degrees = rot_deg
	(bones[bone_name] as Node3D).add_child(s)
	sockets[socket_name] = s
	return s


## Attaches a mesh to a bone.
func part(bone_name: String, mesh: Mesh, mat: Material, pos: Vector3 = Vector3.ZERO, rot_deg: Vector3 = Vector3.ZERO, scl: Vector3 = Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_deg
	mi.scale = scl
	var parent: Node3D = self if bone_name == "" else bones[bone_name]
	parent.add_child(mi)
	return mi


# --- cached primitive meshes ------------------------------------------------------

static func box(size: Vector3) -> Mesh:
	var k := "box%s" % size
	if not _mesh_cache.has(k):
		var m := BoxMesh.new()
		m.size = size
		_mesh_cache[k] = m
	return _mesh_cache[k]


static func capsule(radius: float, height: float) -> Mesh:
	var k := "cap%.3f_%.3f" % [radius, height]
	if not _mesh_cache.has(k):
		var m := CapsuleMesh.new()
		m.radius = radius
		m.height = maxf(height, radius * 2.0)
		m.radial_segments = 16
		m.rings = 6
		_mesh_cache[k] = m
	return _mesh_cache[k]


static func cylinder(top: float, bottom: float, height: float, sides: int = 16) -> Mesh:
	var k := "cyl%.3f_%.3f_%.3f_%d" % [top, bottom, height, sides]
	if not _mesh_cache.has(k):
		var m := CylinderMesh.new()
		m.top_radius = top
		m.bottom_radius = bottom
		m.height = height
		m.radial_segments = sides
		m.rings = 1
		_mesh_cache[k] = m
	return _mesh_cache[k]


static func sphere(radius: float, height: float = -1.0, segments: int = 16) -> Mesh:
	var h := radius * 2.0 if height < 0.0 else height
	var k := "sph%.3f_%.3f_%d" % [radius, h, segments]
	if not _mesh_cache.has(k):
		var m := SphereMesh.new()
		m.radius = radius
		m.height = h
		m.radial_segments = segments
		m.rings = maxi(6, segments >> 1)
		_mesh_cache[k] = m
	return _mesh_cache[k]


static func prism(size: Vector3, left_to_right: float = 0.5) -> Mesh:
	var k := "pri%s_%.2f" % [size, left_to_right]
	if not _mesh_cache.has(k):
		var m := PrismMesh.new()
		m.size = size
		m.left_to_right = left_to_right
		_mesh_cache[k] = m
	return _mesh_cache[k]


static func torus(inner: float, outer: float) -> Mesh:
	var k := "tor%.3f_%.3f" % [inner, outer]
	if not _mesh_cache.has(k):
		var m := TorusMesh.new()
		m.inner_radius = inner
		m.outer_radius = outer
		m.rings = 24
		m.ring_segments = 8
		_mesh_cache[k] = m
	return _mesh_cache[k]


static func cached_mesh(key: String, factory: Callable) -> Mesh:
	if not _mesh_cache.has(key):
		_mesh_cache[key] = factory.call()
	return _mesh_cache[key]
