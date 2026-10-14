extends Node
## Run-time progression state: Ka, levels, persistent world flags and the dropped heart.
## Serialised to JSON by SaveSystem.

signal ka_changed(amount: int)
signal levels_changed
signal flag_changed(flag: StringName, value: bool)
## The active feel preset changed (F7) or one of its values was edited (F6).
signal feel_changed(preset: FeelPreset)

const BALANCE_PATH := "res://resources/balance/balance.tres"
const PLAYER_STATS_PATH := "res://resources/balance/player_stats.tres"
const LEVELING_PATH := "res://resources/balance/leveling.tres"
const STATS: Array[StringName] = [&"vitality", &"strength", &"spirit"]
## Feel presets in F7 order.
const FEEL_PRESET_PATHS: Array[String] = ["res://resources/feel/old.tres", "res://resources/feel/snappy.tres", "res://resources/feel/weighty.tres"]
const DEFAULT_FEEL := &"snappy"

var balance: BalanceConfig
var player_stats: PlayerStats
var leveling: LevelingConfig
var feel_presets: Array[FeelPreset] = []
## Active feel preset (movement, windows, dodge, impact, camera, procedural layers).
var feel: FeelPreset

var ka: int = 0
var levels: Dictionary = {}
var bonus_ankh: int = 0
var last_altar: StringName = &""
var flags: Dictionary = {}
var collected: Dictionary = {}
var has_heart: bool = false
var heart_position: Vector3 = Vector3.ZERO
var heart_ka: int = 0
var deaths: int = 0
var play_time: float = 0.0
## Set when a level should place the player at a specific altar on load (continue / respawn).
var pending_spawn_altar: StringName = &""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	balance = load(BALANCE_PATH) as BalanceConfig
	player_stats = load(PLAYER_STATS_PATH) as PlayerStats
	leveling = load(LEVELING_PATH) as LevelingConfig
	for path in FEEL_PRESET_PATHS:
		feel_presets.append(load(path) as FeelPreset)
	feel = _find_feel(StringName(Settings.feel_preset))
	if feel == null:
		feel = _find_feel(DEFAULT_FEEL)
	reset_progress()


func _process(delta: float) -> void:
	if not get_tree().paused:
		play_time += delta


# --- feel presets ---------------------------------------------------------------

func _find_feel(id: StringName) -> FeelPreset:
	for p in feel_presets:
		if p.id == id:
			return p
	return null


## Activates a feel preset by id. `persist` stores the choice in the user settings.
func set_feel_preset(id: StringName, persist: bool = true) -> void:
	var p := _find_feel(id)
	if p == null:
		push_warning("GameState: unknown feel preset '%s'" % id)
		return
	feel = p
	if persist:
		Settings.feel_preset = String(id)
		Settings.save_settings()
	feel_changed.emit(feel)


## F7: next preset in FEEL_PRESET_PATHS order.
func cycle_feel_preset() -> FeelPreset:
	var i := feel_presets.find(feel)
	set_feel_preset(feel_presets[(i + 1) % feel_presets.size()].id)
	return feel


## Re-reads the active preset from disk, discarding live edits.
func reload_feel_preset() -> void:
	var i := feel_presets.find(feel)
	var p := ResourceLoader.load(feel.resource_path, "", ResourceLoader.CACHE_MODE_REPLACE) as FeelPreset
	if p != null and i >= 0:
		feel_presets[i] = p
		feel = p
	feel_changed.emit(feel)


func reset_progress() -> void:
	ka = 0
	levels = {}
	for s in STATS:
		levels[s] = 0
	bonus_ankh = 0
	last_altar = &""
	flags = {}
	collected = {}
	has_heart = false
	heart_position = Vector3.ZERO
	heart_ka = 0
	deaths = 0
	play_time = 0.0
	pending_spawn_altar = &""
	ka_changed.emit(ka)
	levels_changed.emit()


# --- Ka --------------------------------------------------------------------

func add_ka(amount: int) -> void:
	if amount <= 0:
		return
	ka += amount
	ka_changed.emit(ka)


func spend_ka(amount: int) -> bool:
	if amount > ka:
		return false
	ka -= amount
	ka_changed.emit(ka)
	return true


## Called when the player dies: all carried Ka goes into a heart at the death spot.
## A heart that was not recovered is lost forever.
func drop_heart(at: Vector3) -> void:
	deaths += 1
	if ka > 0:
		has_heart = true
		heart_position = at
		heart_ka = ka
	else:
		has_heart = false
		heart_ka = 0
	ka = 0
	ka_changed.emit(ka)


func recover_heart() -> int:
	if not has_heart:
		return 0
	var amount := heart_ka
	has_heart = false
	heart_ka = 0
	add_ka(amount)
	return amount


# --- Levels ----------------------------------------------------------------

func get_level(stat: StringName) -> int:
	return int(levels.get(stat, 0))


func total_level() -> int:
	var total := 1
	for s in STATS:
		total += get_level(s)
	return total


func level_cost() -> int:
	return leveling.cost_for_level(total_level())


func can_level_up() -> bool:
	return ka >= level_cost()


func level_up(stat: StringName) -> bool:
	if not STATS.has(stat):
		return false
	var cost := level_cost()
	if not spend_ka(cost):
		return false
	levels[stat] = get_level(stat) + 1
	levels_changed.emit()
	return true


func max_hp() -> float:
	return player_stats.max_hp + leveling.hp_per_vitality * get_level(&"vitality")


func melee_multiplier() -> float:
	return 1.0 + leveling.melee_bonus_per_strength * get_level(&"strength")


func spirit_damage_multiplier() -> float:
	return 1.0 + leveling.ranged_bonus_per_spirit * get_level(&"spirit")


func spirit_energy_multiplier() -> float:
	return 1.0 + leveling.energy_gain_bonus_per_spirit * get_level(&"spirit")


func max_ankh() -> int:
	return player_stats.ankh_charges + bonus_ankh


# --- Flags -----------------------------------------------------------------

func set_flag(flag: StringName, value: bool = true) -> void:
	if bool(flags.get(flag, false)) == value:
		return
	flags[flag] = value
	flag_changed.emit(flag, value)


func get_flag(flag: StringName) -> bool:
	return bool(flags.get(flag, false))


func mark_collected(id: StringName) -> void:
	collected[id] = true


func is_collected(id: StringName) -> bool:
	return bool(collected.get(id, false))


# --- Serialisation -----------------------------------------------------------

func to_dict() -> Dictionary:
	return {
		"ka": ka,
		"levels": levels.duplicate(),
		"bonus_ankh": bonus_ankh,
		"last_altar": String(last_altar),
		"flags": flags.duplicate(),
		"collected": collected.duplicate(),
		"heart": {
			"has": has_heart,
			"pos": [heart_position.x, heart_position.y, heart_position.z],
			"ka": heart_ka,
		},
		"deaths": deaths,
		"play_time": play_time,
	}


func from_dict(d: Dictionary) -> void:
	reset_progress()
	ka = int(d.get("ka", 0))
	var lv: Dictionary = d.get("levels", {})
	for s in STATS:
		levels[s] = int(lv.get(String(s), 0))
	bonus_ankh = int(d.get("bonus_ankh", 0))
	last_altar = StringName(str(d.get("last_altar", "")))
	var f: Dictionary = d.get("flags", {})
	for k: Variant in f:
		flags[StringName(str(k))] = bool(f[k])
	var c: Dictionary = d.get("collected", {})
	for k: Variant in c:
		collected[StringName(str(k))] = bool(c[k])
	var h: Dictionary = d.get("heart", {})
	has_heart = bool(h.get("has", false))
	var p: Array = h.get("pos", [0.0, 0.0, 0.0])
	if p.size() == 3:
		heart_position = Vector3(float(p[0]), float(p[1]), float(p[2]))
	heart_ka = int(h.get("ka", 0))
	deaths = int(d.get("deaths", 0))
	play_time = float(d.get("play_time", 0.0))
	ka_changed.emit(ka)
	levels_changed.emit()
