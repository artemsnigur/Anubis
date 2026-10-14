extends CanvasLayer
## End of the vertical slice: summary and return to the title screen.

const TITLE_SCENE := "res://scenes/ui/title_menu.tscn"

var _root: Control
var _done: bool = false


func _ready() -> void:
	layer = 45
	process_mode = Node.PROCESS_MODE_ALWAYS


func show_end() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIStyle.theme()
	add_child(_root)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = Color(0.02, 0.03, 0.08, 0.0)
	_root.add_child(bg)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 18)
	center.add_child(box)
	var icons := HBoxContainer.new()
	icons.alignment = BoxContainer.ALIGNMENT_CENTER
	icons.add_theme_constant_override(&"separation", 60)
	box.add_child(icons)
	var heart := DuatIcon.new(DuatIcon.Kind.HEART, 64.0)
	heart.color = Color(0.85, 0.2, 0.15)
	icons.add_child(heart)
	var feather := DuatIcon.new(DuatIcon.Kind.FEATHER, 64.0)
	feather.color = Color(0.96, 0.94, 0.86)
	icons.add_child(feather)
	var title := UIStyle.label("YOUR HEART IS LIGHTER THAN THE FEATHER", 52, UIStyle.GOLD, true)
	title.add_theme_constant_override(&"outline_size", 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var t := int(GameState.play_time)
	var stats := UIStyle.label("Time %d:%02d    Deaths %d    Level %d    Ka %d" % [t / 60, t % 60, GameState.deaths, GameState.total_level(), GameState.ka], 26, UIStyle.PAPYRUS)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(stats)
	var thanks := UIStyle.label("The gates of the Field of Reeds open before you.\nEnd of the vertical slice - thank you for playing.", 24, UIStyle.PAPYRUS)
	thanks.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(thanks)
	var btn := UIStyle.button("Return to title", _to_title)
	box.add_child(btn)
	_root.modulate.a = 0.0
	var tw := create_tween().set_ignore_time_scale(true)
	tw.tween_property(bg, "color:a", 0.85, 2.0)
	tw.parallel().tween_property(_root, "modulate:a", 1.0, 2.0)
	tw.tween_callback(btn.grab_focus)
	AudioManager.play_event(&"victory")


func _to_title() -> void:
	if _done:
		return
	_done = true
	get_tree().paused = false
	get_tree().change_scene_to_file(TITLE_SCENE)
