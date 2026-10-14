extends Node
## Capture helper: drives the player to attack the dummy in front of it.

var player: Player
var _t: float = 0.0
var _presses: Array = []


func setup(scene: Node, args: Dictionary) -> void:
	player = scene.get("player")
	player.input.bot_enabled = true
	player.teleport_to(Vector3(0.0, 0.1, 1.9), 0.0)
	var cam := scene.get("camera") as GameCamera
	cam.zoom = float(args.get("zoom", "1.0"))
	cam.call_deferred(&"snap_to_target")
	var kind := String(args.get("action", "light"))
	match kind:
		"light":
			_presses = [[1.5, &"attack_light"], [1.75, &"attack_light"], [2.05, &"attack_light"]]
		"heavy":
			_presses = [[1.5, &"attack_heavy"]]
		"ranged":
			player.energy = 4.0
			player.teleport_to(Vector3(0.0, 0.1, 6.0), 0.0)
			_presses = [[1.5, &"ranged"]]
		"dodge":
			_presses = [[1.5, &"dodge"]]


func _physics_process(delta: float) -> void:
	_t += delta
	for p: Array in _presses:
		if absf(_t - float(p[0])) < delta * 0.5:
			player.input.bot_press(p[1])
	player.input.bot_aim = Vector3.FORWARD
