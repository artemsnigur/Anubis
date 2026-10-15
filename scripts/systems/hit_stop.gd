extends Node
## Hitstop service.
## Local hitstop (default) freezes only the involved combatants: their animation,
## state timers and movement stop while the rest of the world keeps running.
## Global slow motion via Engine.time_scale is reserved for special moments.

var _slowmo_until_msec: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


## Freezes every node in `targets` that implements apply_hitstop(duration).
## The active FeelPreset scales light and heavy hits separately (heavy = heavy attacks
## and finishers with a long base hitstop).
func freeze(targets: Array, duration: float, heavy: bool = false) -> void:
	var f := GameState.feel
	var mult := f.hitstop_heavy_mult if heavy else f.hitstop_light_mult
	var d := minf(duration * GameState.balance.hitstop_multiplier * mult, GameState.balance.max_hitstop)
	if d <= 0.0:
		return
	for t: Variant in targets:
		if t is Node and is_instance_valid(t) and (t as Node).has_method(&"apply_hitstop"):
			(t as Node).call(&"apply_hitstop", d)


## Global slow motion for `real_duration` seconds of real time.
func slow_motion(scale: float, real_duration: float) -> void:
	Engine.time_scale = scale
	var until := Time.get_ticks_msec() + int(real_duration * 1000.0)
	_slowmo_until_msec = maxi(_slowmo_until_msec, until)
	await get_tree().create_timer(real_duration, true, false, true).timeout
	if Time.get_ticks_msec() >= _slowmo_until_msec - 5:
		Engine.time_scale = 1.0


func reset() -> void:
	_slowmo_until_msec = 0
	Engine.time_scale = 1.0
