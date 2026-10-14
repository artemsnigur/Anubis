extends Level
## The Necropolis: one interconnected zone.
##  1. Sunlit courtyard (first altar, mummies + scarabs)            y = 0
##  2. Descent into the tomb: antechamber, spike-trap corridor       y = -4
##  3. Hall of Pillars (jackal ambush) -> side room with the +1 Ankh reward
##  4. Gallery of the Dead -> stairs up -> lever opens the shortcut gate into the courtyard
##  5. Antechamber of Judgement (second altar) -> sand veil -> Hall of Two Truths (Ammit)
## Rooms are carved out of solid rock (Carver); the camera dithers away rock in front of the player.

const MUMMY := preload("res://scenes/enemies/mummy.tscn")
const SCARAB := preload("res://scenes/enemies/scarab.tscn")
const JACKAL := preload("res://scenes/enemies/jackal.tscn")
const COBRA := preload("res://scenes/enemies/cobra.tscn")
const BOSS_ARENA_SCRIPT := "res://scripts/world/boss_arena.gd"

const TY := -4.0           # tomb floor
const TOP := -1.2          # rock top: low walls keep the 3/4 camera view open
const CARVE_BOUNDS := Rect2i(-48, -148, 94, 146)

## Carved rooms (x, z, width, depth) - z grows to the south.
const ROOMS := {
	"stairs": Rect2i(-3, -12, 6, 10),
	"ante": Rect2i(-9, -25, 18, 13),
	"corridor": Rect2i(-2, -43, 4, 18),
	"hall": Rect2i(-14, -67, 28, 24),
	"west_pass": Rect2i(-20, -57, 6, 4),
	"side": Rect2i(-32, -63, 12, 16),
	"east_pass": Rect2i(14, -57, 8, 4),
	"gallery": Rect2i(22, -67, 8, 55),
	"gallery_stairs": Rect2i(23, -12, 6, 10),
	"north_pass": Rect2i(-2, -77, 4, 10),
	"altar_room": Rect2i(-8, -89, 16, 12),
	"veil_pass": Rect2i(-3, -93, 6, 4),
	"arena": Rect2i(-18, -129, 36, 36),
	"exit_pass": Rect2i(-3, -137, 6, 8),
}

## Atmosphere zones, first match wins: [rect, preset, banner title, banner subtitle]
var zones: Array = [
	[Rect2(-18, -129, 36, 40), &"hall", "Hall of Two Truths", "Where hearts are weighed"],
	[Rect2(-32, -63, 12, 16), &"tomb", "Chamber of the Canopic Shrine", ""],
	[Rect2(-14, -67, 28, 24), &"tomb", "Hall of Pillars", ""],
	[Rect2(-8, -89, 16, 12), &"tomb", "Antechamber of Judgement", "The Devourer waits beyond the veil"],
	[Rect2(22, -67, 8, 55), &"tomb", "Gallery of the Dead", ""],
	[Rect2(-9, -25, 18, 13), &"tomb", "Descent into the Tomb", ""],
	[Rect2(-48, -148, 94, 140), &"tomb", "", ""],
	[Rect2(-80, -10, 160, 100), &"courtyard", "", ""],
]
## Ambush triggers: [rect, spawner]
var ambushes: Array = []
var shortcut_gate: Gate
var lever: Lever
var veil: SandVeil
var exit_gate: Gate
var boss_arena: Node3D
var _zone_t: float = 0.0
var _zone_current: StringName = &""
var _seen_banners: Dictionary = {}
var _ended: bool = false


func _init() -> void:
	level_name = "The Necropolis"
	start_position = Vector3(0, 0.1, 26.5)
	start_yaw = 0.0
	initial_atmosphere = &"courtyard"


func _build_world() -> void:
	_build_courtyard()
	_build_tomb()
	_build_shortcut()
	_build_arena()


# --- helpers ------------------------------------------------------------------------

func _floor(r: Rect2i, y: float, mat_name: StringName) -> void:
	Kit.floor_rect(nav_region, Rect2(r.position, r.size), y, Mats.get_mat(mat_name))


func _wall_x(z: float, x0: float, x1: float, h: float, t: float, mat: StringName, y: float = 0.0) -> void:
	Kit.box(nav_region, Vector3((x0 + x1) * 0.5, y + h * 0.5, z), Vector3(x1 - x0, h, t), Mats.get_mat(mat))


func _wall_z(x: float, z0: float, z1: float, h: float, t: float, mat: StringName, y: float = 0.0) -> void:
	Kit.box(nav_region, Vector3(x, y + h * 0.5, (z0 + z1) * 0.5), Vector3(t, h, z1 - z0), Mats.get_mat(mat))


func _torch(pos: Vector3, facing: Vector3, energy: float = 2.4) -> void:
	Kit.torch(self, pos, facing, energy)


func _spawner(scene: PackedScene, pos: Vector3, yaw_deg: float = 0.0, count: int = 1, patrol: Array[Vector3] = [], deferred: bool = false) -> EnemySpawner:
	var s := EnemySpawner.new()
	s.enemy_scene = scene
	s.count = count
	s.patrol_points = patrol
	s.deferred = deferred
	add_child(s)
	s.position = pos
	s.rotation_degrees = Vector3(0, yaw_deg, 0)
	return s


func _altar(id: StringName, pos: Vector3, yaw_deg: float, display: String = "Altar of Osiris") -> Altar:
	var a := Altar.new()
	a.altar_id = id
	a.display_name = display
	nav_region.add_child(a)
	a.position = pos
	a.rotation_degrees = Vector3(0, yaw_deg, 0)
	return a


func room_center(key: String, y: float = TY) -> Vector3:
	var r: Rect2i = ROOMS[key]
	return Vector3(r.position.x + r.size.x * 0.5, y, r.position.y + r.size.y * 0.5)


# --- 1. courtyard -----------------------------------------------------------------

func _build_courtyard() -> void:
	# Desert all around (slightly below the courtyard paving) and distant cliffs.
	Kit.floor_rect(nav_region, Rect2(-80, -2, 160, 92), -0.05, Mats.get_mat(&"desert"))
	_floor(Rect2i(-16, 0, 32, 32), 0.0, &"sandstone_floor")
	_floor(Rect2i(-3, -2, 6, 2), 0.0, &"sandstone_floor")
	for c: Array in [[Vector3(-40, 4, 50), Vector3(30, 8, 12)], [Vector3(30, 5, 58), Vector3(40, 10, 10)], [Vector3(-60, 3, 20), Vector3(12, 6, 40)], [Vector3(58, 4, 30), Vector3(12, 8, 50)]]:
		Kit.box(self, c[0], c[1], Mats.get_mat(&"sandstone"))
	for i in 18:
		var a := float(i) * 0.9
		var dp := Vector3(cos(a) * (28.0 + float(i % 5) * 4.0), -0.25, 16.0 + sin(a) * (26.0 + float(i % 3) * 5.0))
		if dp.z > 6.0 and absf(dp.x) > 22.0 or dp.z > 40.0:
			Kit.sand_drift(self, dp, 4.0 + float(i % 4), 0.9)
	# Walls (6 m), thick north wall with the pylon gate, east wall with the shortcut gate.
	var wm := &"courtyard_wall"
	_wall_x(-1.0, -18.0, -3.0, 6.0, 2.0, wm)
	_wall_x(-1.0, 3.0, 18.0, 6.0, 2.0, wm)
	_wall_x(33.0, -18.0, 18.0, 4.0, 2.0, wm)
	_wall_z(-17.0, -2.0, 34.0, 4.0, 2.0, wm)
	_wall_z(17.0, -2.0, 4.0, 4.5, 2.0, wm)
	_wall_z(17.0, 8.0, 34.0, 4.0, 2.0, wm)
	Kit.pylon(nav_region, Vector3(-7.5, 0, -1.5), 8.0, 3.2, 9.0)
	Kit.pylon(nav_region, Vector3(7.5, 0, -1.5), 8.0, 3.2, 9.0)
	Kit.arch(nav_region, Vector3(0, 0, -1.0), 0.0, 6.0, 6.5, 2.4)
	Kit.obelisk(nav_region, Vector3(-5.5, 0, 3.5), 7.5)
	Kit.obelisk(nav_region, Vector3(5.5, 0, 3.5), 7.5)
	# Ruins and statues.
	Kit.statue(nav_region, Vector3(12.5, 0, 25), -90.0, 1.0, true)
	Kit.statue(nav_region, Vector3(-12.5, 0, 13), 90.0, 1.0, false, true)
	Kit.statue(nav_region, Vector3(12.5, 0, 12), -90.0)
	Kit.broken_column(nav_region, Vector3(-11.5, 0, 20), 2.6, 30.0)
	Kit.broken_column(nav_region, Vector3(10.5, 0, 18.5), 1.8, 200.0)
	Kit.column(nav_region, Vector3(-12, 0, 5), 5.5)
	Kit.column(nav_region, Vector3(12, 0, 5.5), 5.5)
	Kit.column(nav_region, Vector3(-12, 0, 28), 5.5)
	Kit.rubble(self, Vector3(-9, 0, 18), 7, 1.6, 11)
	Kit.rubble(self, Vector3(9, 0, 21), 6, 1.4, 12)
	Kit.rubble(self, Vector3(3, 0, 8), 4, 1.0, 13)
	for p: Vector3 in [Vector3(-14, -0.12, 30), Vector3(14, -0.12, 2), Vector3(-14, -0.12, 2), Vector3(6, -0.15, 31), Vector3(-4, -0.18, 15)]:
		Kit.sand_drift(self, p, 2.4, 0.3)
	# First altar with braziers.
	_altar(&"courtyard", Vector3(-11, 0, 25), -90.0)
	Kit.brazier(nav_region, Vector3(-12, 0, 21.5), 2.2, 7.0)
	Kit.brazier(nav_region, Vector3(-12, 0, 28.5), 2.2, 7.0)
	Kit.offering_table(nav_region, Vector3(0, 0, 4.5), 0.0)
	# Reflecting lotus pool in front of the start, papyrus at its corners.
	Kit.pool(nav_region, Rect2(-4.5, 17.0, 9.0, 4.5))
	for pp: Vector3 in [Vector3(-5.6, 0, 16.4), Vector3(5.6, 0, 22.3), Vector3(-5.4, 0, 22.6), Vector3(5.2, 0, 16.2)]:
		Kit.papyrus(self, pp, 11, int(pp.x * 10.0 + pp.z))
	Kit.jars(self, Vector3(14, 0, 30), 5, 21)
	Kit.jars(self, Vector3(-14, 0, 9), 4, 22)
	Kit.wind_sand(self, Vector3(4, 0.5, 16), Vector3(16, 0.4, 16))
	# Enemies: tutorial mummies and a scarab swarm.
	var patrol: Array[Vector3] = [Vector3(-5, 0, 11.5), Vector3(5, 0, 11.5)]
	_spawner(MUMMY, Vector3(0, 0, 11.5), 180.0, 1, patrol)
	_spawner(MUMMY, Vector3(-7, 0, 7), 150.0)
	_spawner(SCARAB, Vector3(8, 0, 10), 200.0, 5)


# --- 2-5. tomb ----------------------------------------------------------------------

func _build_tomb() -> void:
	var rooms: Array = []
	for k: String in ROOMS:
		rooms.append(ROOMS[k])
	var n := Carver.carve(nav_region, CARVE_BOUNDS, rooms, TY - 0.6, TOP, Mats.get_mat(&"tomb_block"))
	print("Necropolis: carved rock into %d blocks" % n)
	for k: String in ROOMS:
		if k.contains("stairs"):
			continue
		_floor(ROOMS[k], TY, &"hall_floor" if k == "arena" else &"tomb_floor")
	Kit.stairs(nav_region, Vector3(0, TY, -12), Vector3(0, 0, -2), 6.0, Mats.get_mat(&"sandstone"), true)
	Kit.stairs(nav_region, Vector3(26, TY, -12), Vector3(26, 0, -2), 6.0, Mats.get_mat(&"sandstone"), true)
	_build_antechamber()
	_build_trap_corridor()
	_build_hall_of_pillars()
	_build_side_room()
	_build_gallery()
	_build_altar_room()


func _build_antechamber() -> void:
	Kit.statue(nav_region, Vector3(-5.5, TY, -23), 0.0, 0.9, false, true)
	Kit.statue(nav_region, Vector3(5.5, TY, -23), 0.0, 0.9, false, true)
	Kit.sarcophagus(nav_region, Vector3(-6, TY, -16), 90.0)
	Kit.jars(self, Vector3(7, TY, -14), 5, 31)
	Kit.jars(self, Vector3(-7.5, TY, -20.5), 3, 32)
	for z: float in [-15.0, -21.0]:
		_torch(Vector3(-8.75, TY + 2.0, z), Vector3.RIGHT)
		_torch(Vector3(8.75, TY + 2.0, z), Vector3.LEFT)
	_torch(Vector3(-4.5, TY + 2.0, -24.75), Vector3.BACK)
	_torch(Vector3(4.5, TY + 2.0, -24.75), Vector3.BACK)
	Kit.dust_motes(self, room_center("ante", TY + 2.0), Vector3(8, 2, 6))
	_spawner(COBRA, Vector3(6, TY, -19), 220.0)
	_spawner(SCARAB, Vector3(-4, TY, -19), 160.0, 4)


func _build_trap_corridor() -> void:
	for z: float in [-29.0, -34.5, -40.0]:
		var trap := SpikeTrap.new()
		trap.field_size = Vector2(4.0, 2.5)
		trap.plate_offset = Vector3(0.9 if int(z) % 2 == 0 else -0.9, 0, 1.6)
		trap.field_offset = Vector3(0, 0, -0.6)
		add_child(trap)
		trap.position = Vector3(0, TY, z)
	for z: float in [-27.0, -32.0, -37.5, -42.0]:
		_torch(Vector3(-1.75, TY + 1.9, z), Vector3.RIGHT, 1.8)
		_torch(Vector3(1.75, TY + 1.9, z), Vector3.LEFT, 1.8)


func _build_hall_of_pillars() -> void:
	for x: float in [-9.0, -3.0, 3.0, 9.0]:
		for z: float in [-49.0, -55.0, -61.0]:
			Kit.column(nav_region, Vector3(x, TY, z), 5.4, 0.6)
	Kit.statue(nav_region, Vector3(-4.8, TY, -64.8), 0.0, 0.85, false, true)
	Kit.statue(nav_region, Vector3(4.8, TY, -64.8), 0.0, 0.85, false, true)
	for p: Vector3 in [Vector3(-12, TY, -45), Vector3(12, TY, -45), Vector3(-12, TY, -65), Vector3(12, TY, -65)]:
		Kit.brazier(nav_region, p, 2.6, 8.0)
	for z: float in [-47.0, -62.0]:
		_torch(Vector3(-13.75, TY + 2.0, z), Vector3.RIGHT)
		_torch(Vector3(13.75, TY + 2.0, z), Vector3.LEFT)
	Kit.dust_motes(self, room_center("hall", TY + 2.0), Vector3(13, 2, 11), 110)
	Kit.rubble(self, Vector3(-6, TY, -52), 4, 1.0, 41)
	# Ambush: two jackals burst from the sand when the player steps into the hall.
	var a1 := _spawner(JACKAL, Vector3(-6, TY, -51), 180.0, 1, [], true)
	var a2 := _spawner(JACKAL, Vector3(6, TY, -51), 180.0, 1, [], true)
	ambushes.append([Rect2(-14, -47, 28, 4), a1])
	ambushes.append([Rect2(-14, -47, 28, 4), a2])
	_spawner(COBRA, Vector3(9, TY, -64), 160.0)
	var patrol: Array[Vector3] = [Vector3(-11, TY, -59), Vector3(-11, TY, -47)]
	_spawner(MUMMY, Vector3(-11, TY, -59), 0.0, 1, patrol)


func _build_side_room() -> void:
	var shrine := RewardShrine.new()
	shrine.reward_id = &"side_room_ankh"
	nav_region.add_child(shrine)
	shrine.position = Vector3(-30, TY, -55)
	shrine.rotation_degrees = Vector3(0, -90, 0)
	Kit.sarcophagus(nav_region, Vector3(-25.5, TY, -50.5), 0.0)
	Kit.sarcophagus(nav_region, Vector3(-25.5, TY, -59.5), 0.0)
	Kit.offering_table(nav_region, Vector3(-30.5, TY, -49), 90.0)
	Kit.jars(self, Vector3(-30.5, TY, -61), 6, 51)
	for z: float in [-50.0, -60.0]:
		_torch(Vector3(-31.75, TY + 2.0, z), Vector3.RIGHT)
	_torch(Vector3(-26, TY + 2.0, -62.75), Vector3.BACK)
	_torch(Vector3(-26, TY + 2.0, -47.25), Vector3.FORWARD)
	var glow := OmniLight3D.new()
	glow.light_color = Color(0.3, 1.0, 0.8)
	glow.light_energy = 1.5
	glow.omni_range = 6.0
	glow.position = Vector3(-29, TY + 3.0, -55)
	add_child(glow)
	Kit.dust_motes(self, room_center("side", TY + 2.0), Vector3(5, 2, 7))
	_spawner(JACKAL, Vector3(-23, TY, -55), 90.0)
	var swarm := _spawner(SCARAB, Vector3(-27, TY, -55), 90.0, 4, [], true)
	ambushes.append([Rect2(-32, -60, 7, 10), swarm])


func _build_gallery() -> void:
	for z in range(-62, -16, 7):
		Kit.column(nav_region, Vector3(23.6, TY, float(z)), 5.2, 0.5)
		Kit.column(nav_region, Vector3(28.4, TY, float(z)), 5.2, 0.5)
		_torch(Vector3(22.25, TY + 2.0, float(z) + 3.5), Vector3.RIGHT, 2.0)
		_torch(Vector3(29.75, TY + 2.0, float(z) + 3.5), Vector3.LEFT, 2.0)
	Kit.sarcophagus(nav_region, Vector3(26, TY, -65), 90.0)
	Kit.dust_motes(self, room_center("gallery", TY + 2.0), Vector3(3, 2, 26), 120)
	_spawner(MUMMY, Vector3(26, TY, -58), 0.0)
	_spawner(COBRA, Vector3(26, TY, -43), 0.0)
	_spawner(JACKAL, Vector3(26, TY, -31), 0.0)
	_spawner(SCARAB, Vector3(26, TY, -21), 0.0, 4)


func _build_altar_room() -> void:
	_altar(&"judgement", Vector3(-6, TY, -83), -90.0, "Altar of Osiris")
	Kit.brazier(nav_region, Vector3(6, TY, -79), 2.4, 8.0)
	Kit.brazier(nav_region, Vector3(6, TY, -87), 2.4, 8.0)
	Kit.offering_table(nav_region, Vector3(6, TY, -83), 90.0)
	Kit.statue(nav_region, Vector3(-5.5, TY, -79), 90.0, 0.7, false, true)
	Kit.statue(nav_region, Vector3(-5.5, TY, -87), 90.0, 0.7, false, true)
	for x: float in [-1.75, 1.75]:
		_torch(Vector3(x, TY + 1.9, -72), Vector3.RIGHT if x < 0.0 else Vector3.LEFT, 1.8)
	# A shaft of light falling onto the altar room.
	var shaft := SpotLight3D.new()
	shaft.light_color = Color(1.0, 0.86, 0.6)
	shaft.light_energy = 5.0
	shaft.spot_range = 14.0
	shaft.spot_angle = 22.0
	shaft.light_volumetric_fog_energy = 3.0
	shaft.shadow_enabled = true
	add_child(shaft)
	shaft.position = Vector3(0, TY + 10.0, -83)
	shaft.rotation_degrees = Vector3(-90, 0, 0)
	Kit.dust_motes(self, Vector3(0, TY + 3.0, -83), Vector3(2.5, 3, 2.5), 80)
	veil = SandVeil.new()
	veil.width = 6.0
	veil.height = 3.0
	add_child(veil)
	veil.position = Vector3(0, TY, -91.5)


# --- shortcut: gallery stairs -> vestibule -> lever -> gate into the courtyard -------

func _build_shortcut() -> void:
	_floor(Rect2i(18, -2, 12, 12), 0.0, &"tomb_floor")
	_wall_x(-3.0, 16.0, 23.0, 4.0, 2.0, &"courtyard_wall")
	_wall_x(-3.0, 29.0, 32.0, 4.0, 2.0, &"courtyard_wall")
	_wall_z(31.0, -4.0, 12.0, 5.0, 2.0, &"courtyard_wall")
	_wall_x(11.0, 16.0, 32.0, 5.0, 2.0, &"courtyard_wall")
	shortcut_gate = Gate.new()
	shortcut_gate.gate_id = &"shortcut"
	shortcut_gate.width = 4.0
	shortcut_gate.height = 5.0
	nav_region.add_child(shortcut_gate)
	shortcut_gate.opened.connect(rebake_navigation)
	shortcut_gate.position = Vector3(17, 0, 6)
	shortcut_gate.rotation_degrees = Vector3(0, 90, 0)
	lever = Lever.new()
	lever.flag = &"shortcut_open"
	lever.gate = shortcut_gate
	nav_region.add_child(lever)
	lever.position = Vector3(20.5, 0, 9.0)
	lever.rotation_degrees = Vector3(0, 90, 0)
	Kit.statue(nav_region, Vector3(28.5, 0, 6), -90.0, 0.8, true)
	Kit.jars(self, Vector3(28.5, 0, 0), 4, 61)
	_torch(Vector3(29.75, 2.4, 2), Vector3.LEFT)
	_torch(Vector3(18.25, 2.4, 1), Vector3.RIGHT)


# --- Hall of Two Truths ------------------------------------------------------------

func _build_arena() -> void:
	var r: Rect2i = ROOMS["arena"]
	var x0 := float(r.position.x)
	var x1 := float(r.end.x)
	var z0 := float(r.position.y)
	var z1 := float(r.end.y)
	# Basalt wall skins with glowing gold inscriptions.
	var wh := TOP - TY + 0.05
	_wall_x(z0 + 0.15, x0, -3.0, wh, 0.3, &"hall_wall", TY)
	_wall_x(z0 + 0.15, 3.0, x1, wh, 0.3, &"hall_wall", TY)
	_wall_x(z1 - 0.15, x0, -3.0, wh, 0.3, &"hall_wall", TY)
	_wall_x(z1 - 0.15, 3.0, x1, wh, 0.3, &"hall_wall", TY)
	_wall_z(x0 + 0.15, z0, z1, wh, 0.3, &"hall_wall", TY)
	_wall_z(x1 - 0.15, z0, z1, wh, 0.3, &"hall_wall", TY)
	for z: float in [-97.0, -105.0, -117.0, -125.0]:
		for x: float in [-15.0, 15.0]:
			Kit.column(nav_region, Vector3(x, TY, z), 6.0, 0.6, Mats.get_mat(&"basalt_glyph"), Mats.get_mat(&"gold_world"))
	var key := 0
	for p: Vector3 in [Vector3(-14, TY, -96.5), Vector3(14, TY, -96.5), Vector3(-14, TY, -125.5), Vector3(14, TY, -125.5)]:
		Kit.brazier(nav_region, p, 3.2, 11.0, key < 2)
		key += 1
	for p: Vector3 in [Vector3(-16.5, TY, -111), Vector3(16.5, TY, -111)]:
		Kit.brazier(nav_region, p, 2.8, 10.0)
	var sky := OmniLight3D.new()
	sky.light_color = Color(1.0, 0.82, 0.5)
	sky.light_energy = 2.6
	sky.omni_range = 22.0
	sky.omni_attenuation = 0.8
	sky.light_volumetric_fog_energy = 1.5
	add_child(sky)
	sky.position = Vector3(0, TY + 9.0, (z0 + z1) * 0.5)
	exit_gate = Gate.new()
	exit_gate.gate_id = &"exit"
	exit_gate.width = 6.0
	exit_gate.height = 5.5
	nav_region.add_child(exit_gate)
	exit_gate.opened.connect(rebake_navigation)
	exit_gate.position = Vector3(0, TY, z0 - 0.3)
	_torch(Vector3(-2.75, TY + 1.9, -133), Vector3.RIGHT)
	_torch(Vector3(2.75, TY + 1.9, -133), Vector3.LEFT)
	Kit.dust_motes(self, Vector3(0, TY + 3.0, (z0 + z1) * 0.5), Vector3(16, 3, 16), 160)
	if ResourceLoader.exists(BOSS_ARENA_SCRIPT):
		boss_arena = (load(BOSS_ARENA_SCRIPT) as GDScript).new() as Node3D
		boss_arena.name = "BossArena"
		boss_arena.position = Vector3((x0 + x1) * 0.5, TY, (z0 + z1) * 0.5)
		add_child(boss_arena)


# --- persistence / runtime -----------------------------------------------------------

func _apply_persistent_state() -> void:
	if GameState.get_flag(&"shortcut_open"):
		shortcut_gate.open(true)
		lever.set_pulled(true)
	if GameState.get_flag(&"boss_defeated"):
		exit_gate.open(true)
	if boss_arena != null:
		boss_arena.call(&"apply_state")


func _on_world_reset() -> void:
	for t in get_tree().get_nodes_in_group(&"traps"):
		(t as SpikeTrap).reset()
	if veil != null:
		veil.drop_veil(true)
	if boss_arena != null:
		boss_arena.call(&"reset_arena")


func _level_started() -> void:
	fader.fade_in(1.2)
	if GameState.last_altar == &"":
		hud.show_banner("The Sunlit Courtyard", "The Necropolis of the Duat")
		_seen_banners["The Sunlit Courtyard"] = true


func _process(delta: float) -> void:
	if player == null or player.is_dead:
		return
	_zone_t -= delta
	if _zone_t > 0.0:
		return
	_zone_t = 0.2
	var p := Vector2(player.global_position.x, player.global_position.z)
	for z: Array in zones:
		if (z[0] as Rect2).has_point(p):
			var preset: StringName = z[1]
			if preset == &"hall" and boss_arena != null and bool(boss_arena.get("phase_two")):
				preset = &"hall_rage"
			if preset != _zone_current:
				_zone_current = preset
				atmosphere.apply_preset(preset)
				screen_fx.set_grade(Color(0.9, 0.96, 1.1) if preset != &"courtyard" else Color(0.95, 0.96, 1.04), Color(1.08, 1.0, 0.9))
			var title: String = z[2]
			if title != "" and not _seen_banners.has(title):
				_seen_banners[title] = true
				hud.show_banner(title, String(z[3]))
			break
	for a: Array in ambushes:
		var sp := a[1] as EnemySpawner
		if not sp.triggered and (a[0] as Rect2).has_point(p):
			sp.trigger(enemies_root)
	if not _ended and GameState.get_flag(&"boss_defeated") and Rect2(-3, -137, 6, 6).has_point(p):
		_ended = true
		_finish_slice()


func _finish_slice() -> void:
	pause_menu.allowed = false
	SaveSystem.save_game()
	var screen_script := load("res://scripts/ui/victory_screen.gd") as GDScript
	if screen_script != null:
		var vs: CanvasLayer = screen_script.new()
		add_child(vs)
		vs.call(&"show_end")
