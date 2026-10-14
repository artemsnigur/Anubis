extends Node
## Capture helper for UI screens: --ui=hud|levelup|death|pause

var level: Level
var mode: String


func setup(scene: Node, args: Dictionary) -> void:
	level = scene as Level
	mode = String(args.get("ui", "hud"))
	GameState.add_ka(640)
	_go.call_deferred()


func _go() -> void:
	await get_tree().create_timer(0.6).timeout
	var p := level.player
	p.health.current = 64.0
	p.energy = 2.5
	p.ankh = 2
	p.stamina = 55.0
	match mode:
		"levelup":
			level.levelup.open()
		"death":
			level.hud.set_visible_hud(false)
			level.death_screen.show_death(640, false)
		"pause":
			level.pause_menu.open()
		"boss":
			level.hud.show_boss(p, "Ammit, Devourer of Hearts")
			level.hud.show_banner("The Hall of Two Truths", "Where hearts are weighed")
