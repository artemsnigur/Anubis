extends Node
## Boot scene: shows the title menu.

const TITLE_SCENE := "res://scenes/ui/title_menu.tscn"


func _ready() -> void:
	if ResourceLoader.exists(TITLE_SCENE):
		get_tree().change_scene_to_file.call_deferred(TITLE_SCENE)
