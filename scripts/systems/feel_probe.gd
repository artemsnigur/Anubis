extends Node
## Feel instrumentation (autoload "FeelProbe"): measures how fast the hero answers input.
## It watches the player from outside, twice per physics tick:
##   * pre-sample (process_physics_priority -1000, before any gameplay node) reads raw input,
##   * post-sample (+1000, after everything) reads what the game did with it.
## Everything is counted in 60 Hz physics frames; frame 0 = the tick in which the input
## is first visible to the game. Latencies are frame offsets (0 = same frame), durations
## (0 -> 90 % speed, stop, turn, hitstop) count the ticks it took.
## Results feed the F3 overlay; with log_enabled (F6 panel or `-- --feel-log`) every
## measurement is also printed as a `[feel]` line.

signal measured(key: String, frames: int)

const ACTIONS: Array[StringName] = [&"attack_light", &"attack_heavy", &"dodge", &"heal", &"ranged"]
const ACTION_STATES: Array[StringName] = [&"Attack", &"Heavy", &"Dodge", &"Heal", &"Cast"]
const LOCK_KINDS: Array[StringName] = [&"move", &"attack", &"dodge"]
const TIMEOUT_FRAMES := 90
const SHORT := {"attack_light": "light", "attack_heavy": "heavy", "dodge": "dodge", "heal": "heal", "ranged": "cast"}

## Targets of the feel pass, in frames: key -> [min, max]. Used for colouring and by tests/feel_test.
const TARGETS := {
	"move_vel": [0, 0], "move_pose": [0, 1], "move_t90": [5, 7], "stop": [4, 6], "turn": [0, 6],
	"attack_light_pose": [0, 0], "attack_light_active": [6, 8], "dodge_move": [0, 0], "dodge_iframe": [0, 2],
	"xfade_combat": [0, 3], "xfade_loco": [0, 6], "lock_Attack_dodge": [0, 12],
}

var log_enabled: bool = false
## key -> frames of the latest measurement.
var results: Dictionary = {}
## Latest human-readable measurement lines (newest last).
var lines: PackedStringArray = []

var _player: Player
var _post: Node
var _pending: Array[Dictionary] = []
var _prev_move: Vector2 = Vector2.ZERO
var _last_dir: Vector3 = Vector3.ZERO
var _last_dir_frame: int = -100
var _snap: Dictionary = {}
var _entries: Array = []          # [frame, state] entered this tick (from state_changed)
var _frozen_since: Dictionary = {}   # Combatant -> first frozen frame
var _lock: Dictionary = {}
var _xfade_cache: Dictionary = {}


func _ready() -> void:
	process_physics_priority = -1000
	_post = _PostSampler.new()
	_post.name = "PostSample"
	_post.process_physics_priority = 1000
	add_child(_post)
	log_enabled = OS.get_cmdline_user_args().has("--feel-log")


func _find_player() -> Player:
	if _player != null and is_instance_valid(_player) and _player.is_inside_tree():
		return _player
	_player = get_tree().get_first_node_in_group(&"player") as Player
	_pending.clear()
	_snap = {}
	_xfade_cache.clear()
	if _player != null:
		_player.fsm.state_changed.connect(_on_state_changed)
	return _player


func _on_state_changed(_from: StringName, to: StringName) -> void:
	_entries.append([Engine.get_physics_frames(), to])


# --- pre-sample: raw input ----------------------------------------------------------

func _physics_process(_delta: float) -> void:
	if _find_player() == null or _snap.is_empty():
		_prev_move = Vector2.ZERO
		return
	var f := Engine.get_physics_frames()
	var m := _player.input.move_vector()
	var moving := m.length() > 0.1
	var was := _prev_move.length() > 0.1
	var dir := _player.input.screen_to_world(m).normalized() if moving else Vector3.ZERO
	var speed: float = _snap["speed"]
	var run := _player.stats.run_speed
	if moving and not was:
		if _last_dir != Vector3.ZERO and f - _last_dir_frame <= 8 and dir.dot(_last_dir) < -0.7 and speed > 0.5 * run:
			# Keyboard reversal (A -> D usually has a gap frame with no key down).
			_cancel(&"stop")
			_begin(&"turn", f, dir)
		elif speed < 0.5:
			_begin(&"move", f, dir)
	elif moving and was and _last_dir != Vector3.ZERO and dir.dot(_last_dir) < -0.7 and speed > 0.5 * run:
		_begin(&"turn", f, dir)
	elif not moving and was and speed > 0.8 * run:
		_begin(&"stop", f, Vector3.ZERO)
	if moving:
		_last_dir = dir
		_last_dir_frame = f
	_prev_move = m
	if _player.input.enabled and not _player.input.bot_enabled:
		for a in ACTIONS:
			if Input.is_action_just_pressed(a):
				_begin(a, f, dir)


func _begin(kind: StringName, f: int, dir: Vector3) -> void:
	_cancel(kind)
	_pending.append({"kind": kind, "f": f, "dir": dir, "base": _snap.duplicate(), "found": {}, "resp_f": -1, "inv_n": 0})


func _cancel(kind: StringName) -> void:
	for i in range(_pending.size() - 1, -1, -1):
		if _pending[i]["kind"] == kind:
			_pending.remove_at(i)


# --- post-sample: what the game did -------------------------------------------------

func _sample() -> Dictionary:
	var v := _player.velocity
	var flat := Vector3(v.x, 0.0, v.z)
	return {
		"speed": flat.length(), "vel": flat, "yaw": _player.rotation.y, "vis": _player.visual.transform,
		"blend": _player.animator.get_locomotion_blend(),
		"anim": _player.animator.current, "state": _player.fsm.current_name(),
		"active": _player.hitbox.active, "inv": _player.hurtbox.invulnerable, "frozen": _player.frozen_tick,
	}


func _post_sample() -> void:
	if _player == null or not is_instance_valid(_player) or not _player.is_inside_tree():
		return
	var f := Engine.get_physics_frames()
	var s := _sample()
	if not _snap.is_empty():
		for i in range(_pending.size() - 1, -1, -1):
			if _update(_pending[i], s, f):
				_pending.remove_at(i)
		if s["anim"] != _snap["anim"]:
			_record_xfade(_snap["anim"], s["anim"])
		_track_hitstop(f)
		_track_lockout(s, f)
	_entries.clear()
	_snap = s


func _pose_changed(s: Dictionary, base: Dictionary) -> bool:
	if s["anim"] != base["anim"] or absf(float(s["blend"]) - float(base["blend"])) > 0.01:
		return true
	if absf(angle_difference(float(s["yaw"]), float(base["yaw"]))) > deg_to_rad(0.5):
		return true
	var a: Transform3D = s["vis"]
	var b: Transform3D = base["vis"]
	return not a.basis.is_equal_approx(b.basis) or a.origin.distance_to(b.origin) > 0.004


func _entered_action() -> StringName:
	for e: Array in _entries:
		if ACTION_STATES.has(e[1]):
			return e[1]
	return &""


## Returns true when the measurement is complete (or timed out).
func _update(p: Dictionary, s: Dictionary, f: int) -> bool:
	var k: StringName = p["kind"]
	var dt: int = f - int(p["f"])
	var found: Dictionary = p["found"]
	var run := _player.stats.run_speed
	var speed: float = s["speed"]
	match k:
		&"move":
			if not found.has("move_vel") and speed > 0.05:
				_found(p, "move_vel", dt)
			if not found.has("move_pose") and _pose_changed(s, p["base"]):
				_found(p, "move_pose", dt)
			if not found.has("move_t90") and speed >= 0.9 * run:
				_found(p, "move_t90", dt + 1)
			if found.size() == 3:
				_line("move  in→vel %df  in→pose %df  0→90%% %df (%d ms)" % [found["move_vel"], found["move_pose"], found["move_t90"], _ms(found["move_t90"])])
				return true
		&"stop":
			if speed < 0.05:
				_found(p, "stop", dt + 1)
				_line("stop  %df (%d ms)" % [dt + 1, _ms(dt + 1)])
				return true
		&"turn":
			var d: Vector3 = p["dir"]
			if not found.has("turn_face") and absf(angle_difference(float(s["yaw"]), Combatant.yaw_for(d))) < deg_to_rad(10.0):
				_found(p, "turn_face", dt + 1)
			if not found.has("turn_vel") and (s["vel"] as Vector3).dot(d) >= 0.5 * run:
				_found(p, "turn_vel", dt + 1)
			if found.size() == 2:
				var t := maxi(found["turn_face"], found["turn_vel"])
				_found(p, "turn", t)
				_line("turn180  %df (%d ms)  facing %df  velocity %df" % [t, _ms(t), found["turn_face"], found["turn_vel"]])
				return true
		_:
			var key := String(k)
			var entered := _entered_action()
			if int(p["resp_f"]) < 0 and entered != &"":
				p["resp_f"] = f
				_found(p, key + "_resp", dt)
			if not found.has(key + "_pose") and int(p["resp_f"]) >= 0 and _pose_changed(s, _snap):
				_found(p, key + "_pose", dt)
			if int(p["resp_f"]) >= 0:
				if (k == &"attack_light" or k == &"attack_heavy") and not found.has(key + "_active") and bool(s["active"]):
					_found(p, key + "_active", dt)
				if k == &"dodge":
					if not found.has("dodge_move") and s["state"] == &"Dodge" and speed > maxf(float(_snap["speed"]) + 0.5, 1.0):
						_found(p, "dodge_move", dt)
					if bool(s["inv"]) and s["state"] == &"Dodge":
						if not found.has("dodge_iframe"):
							_found(p, "dodge_iframe", dt)
						p["inv_n"] = int(p["inv_n"]) + 1
					elif found.has("dodge_iframe") and not found.has("dodge_iframe_len"):
						_found(p, "dodge_iframe_len", int(p["inv_n"]))
			if _action_done(k, found):
				_line(_action_line(k, found))
				return true
	if dt > TIMEOUT_FRAMES:
		if k != &"move" and k != &"stop" and k != &"turn" and not found.is_empty():
			_line(_action_line(k, found))
		return true
	return false


func _action_done(k: StringName, found: Dictionary) -> bool:
	var key := String(k)
	if not found.has(key + "_resp") or not found.has(key + "_pose"):
		return false
	match k:
		&"attack_light", &"attack_heavy":
			return found.has(key + "_active")
		&"dodge":
			return found.has("dodge_move") and found.has("dodge_iframe_len")
	return true


func _action_line(k: StringName, found: Dictionary) -> String:
	var key := String(k)
	var parts: PackedStringArray = ["%s  in→state %s  in→pose %s" % [SHORT.get(key, key), _fs(found, key + "_resp"), _fs(found, key + "_pose")]]
	if found.has(key + "_active"):
		parts.append("in→hitbox %s" % _fs(found, key + "_active"))
	if k == &"dodge":
		parts.append("in→move %s  in→i-frame %s  i-frames %s" % [_fs(found, "dodge_move"), _fs(found, "dodge_iframe"), _fs(found, "dodge_iframe_len")])
	return "  ".join(parts)


func _fs(found: Dictionary, key: String) -> String:
	return "%df" % int(found[key]) if found.has(key) else "–"


func _found(p: Dictionary, key: String, frames: int) -> void:
	(p["found"] as Dictionary)[key] = frames
	results[key] = frames
	measured.emit(key, frames)


func _ms(frames: int) -> int:
	return roundi(frames * 1000.0 / 60.0)


func _line(text: String) -> void:
	lines.append(text)
	if lines.size() > 8:
		lines.remove_at(0)
	if log_enabled:
		print("[feel] f%d %s" % [Engine.get_physics_frames(), text])


# --- hitstop, crossfades, lockouts --------------------------------------------------------

func _track_hitstop(f: int) -> void:
	var list: Array[Combatant] = [_player]
	for n in get_tree().get_nodes_in_group(&"enemies"):
		var e := n as Combatant
		if e != null and e.global_position.distance_squared_to(_player.global_position) < 100.0:
			list.append(e)
	for c in list:
		var frozen := c.frozen_tick
		if frozen and not _frozen_since.has(c):
			_frozen_since[c] = f
		elif not frozen and _frozen_since.has(c):
			var n := f - int(_frozen_since[c])
			_frozen_since.erase(c)
			var key := "hitstop_player" if c == _player else "hitstop_target"
			results[key] = n
			measured.emit(key, n)
			if c == _player:
				_line("hitstop  %df (%d ms)" % [n, _ms(n)])
	for c: Variant in _frozen_since.keys():
		if not is_instance_valid(c):
			_frozen_since.erase(c)


## Crossfade (in frames) of the AnimationTree transition from -> to.
func xfade_frames(from: StringName, to: StringName) -> int:
	if _player == null:
		return -1
	var key := "%s>%s" % [from, to]
	if not _xfade_cache.has(key):
		var sm := _player.animator.tree.tree_root as AnimationNodeStateMachine
		var t := -1.0
		for i in sm.get_transition_count():
			if sm.get_transition_from(i) == from and sm.get_transition_to(i) == to:
				t = sm.get_transition(i).xfade_time
				break
		_xfade_cache[key] = t
	var x: float = _xfade_cache[key]
	return roundi(x * 60.0) if x >= 0.0 else -1


func clear_xfade_cache() -> void:
	_xfade_cache.clear()


func _record_xfade(from: StringName, to: StringName) -> void:
	var n := xfade_frames(from, to)
	if n < 0:
		return
	results["xfade_last"] = n
	results["xfade:%s>%s" % [from, to]] = n


## Lockout: frames from entering an action state until move / attack / dodge are
## accepted again. Needs the state to report its windows through accepts(kind).
func _track_lockout(s: Dictionary, f: int) -> void:
	var entered := _entered_action()
	if entered != &"":
		_lock = {"state": entered, "f": f, "left": LOCK_KINDS.duplicate()}
	if _lock.is_empty():
		return
	var cur := _player.fsm.current
	var name_now: StringName = s["state"]
	var same: bool = name_now == _lock["state"]
	var left: Array = _lock["left"]
	for kind: StringName in left.duplicate():
		var ok := false
		if same:
			ok = cur != null and cur.has_method(&"accepts") and bool(cur.call(&"accepts", kind))
		else:
			ok = name_now == &"Move" or (kind == &"dodge" and name_now == &"Dodge") \
				or (kind == &"attack" and (name_now == &"Attack" or name_now == &"Heavy"))
		if ok:
			left.erase(kind)
			results["lock_%s_%s" % [_lock["state"], kind]] = f - int(_lock["f"])
	if not same:
		_lock = {}
		return
	if left.is_empty() or f - int(_lock["f"]) > TIMEOUT_FRAMES:
		_lock = {}


# --- overlay ------------------------------------------------------------------------------

func target_ok(key: String, frames: int) -> int:
	## 1 = inside the target, 0 = outside, -1 = no target for this key.
	if not TARGETS.has(key):
		return -1
	var r: Array = TARGETS[key]
	return 1 if frames >= int(r[0]) and frames <= int(r[1]) else 0


func _c(key: String) -> String:
	if not results.has(key):
		return "[color=#777]–[/color]"
	var v := int(results[key])
	var ok := target_ok(key, v)
	var col := "#cfe" if ok < 0 else ("#7f7" if ok == 1 else "#f77")
	return "[color=%s]%df[/color]" % [col, v]


## BBCode block for the F3 overlay.
func overlay_text() -> String:
	var t: PackedStringArray = []
	t.append("[b]FEEL[/b] (60 Hz frames, 0 = same frame; green = on target)")
	t.append("move  in→vel %s  in→pose %s  0→90%% %s  stop %s  turn180 %s" % [_c("move_vel"), _c("move_pose"), _c("move_t90"), _c("stop"), _c("turn")])
	t.append("light  in→pose %s  in→hitbox %s   heavy  in→pose %s  in→hitbox %s" % [_c("attack_light_pose"), _c("attack_light_active"), _c("attack_heavy_pose"), _c("attack_heavy_active")])
	t.append("dodge  in→move %s  in→i-frame %s  i-frames %s   hitstop  self %s  target %s   xfade %s" % [_c("dodge_move"), _c("dodge_iframe"), _c("dodge_iframe_len"), _c("hitstop_player"), _c("hitstop_target"), _c("xfade_last")])
	var locks: PackedStringArray = []
	for st: StringName in ACTION_STATES:
		var parts: PackedStringArray = []
		for kind: StringName in LOCK_KINDS:
			var key := "lock_%s_%s" % [st, kind]
			if results.has(key):
				parts.append("%s %s" % [kind, _c(key)])
		if not parts.is_empty():
			locks.append("%s: %s" % [st, " ".join(parts)])
	if not locks.is_empty():
		t.append("lockout  " + "   ".join(locks))
	for l in lines.slice(maxi(lines.size() - 3, 0)):
		t.append("[color=#9ab]%s[/color]" % l)
	return "\n".join(t)


## Post-sampler child: runs after every gameplay node in the tick.
class _PostSampler:
	extends Node

	func _physics_process(_delta: float) -> void:
		(get_parent() as Node).call(&"_post_sample")
