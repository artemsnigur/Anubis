class_name PlayerState
extends State
## Base for player states: typed access to the Player.

var player: Player


func on_setup() -> void:
	player = actor as Player
