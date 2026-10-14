class_name PauseMenu
extends CanvasLayer
## Pause menu: Resume / Settings / Quit to title. Pauses the scene tree.

signal quit_to_title

var _root: Control
var _main: VBoxContainer
var _settings: SettingsPanel
var _resume: Button
var is_open: bool = false
## Set false while other menus (level-up, death) own the screen.
var allowed: bool = true


func _ready() -> void:
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIStyle.theme()
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0.0, 0.02, 0.06, 0.65)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var stack := VBoxContainer.new()
	center.add_child(stack)
	_main = VBoxContainer.new()
	_main.add_theme_constant_override(&"separation", 14)
	stack.add_child(_main)
	var title := UIStyle.label("PAUSED", 56, UIStyle.GOLD, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main.add_child(title)
	_resume = UIStyle.button("Resume", close)
	_main.add_child(_resume)
	_main.add_child(UIStyle.button("Settings", _open_settings))
	_main.add_child(UIStyle.button("Quit to title", func() -> void:
		close()
		quit_to_title.emit()))
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(_close_settings)
	stack.add_child(_settings)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"pause"):
		if is_open:
			if _settings.visible:
				_close_settings()
			else:
				close()
			get_viewport().set_input_as_handled()
		elif allowed:
			open()
			get_viewport().set_input_as_handled()
	elif is_open and event.is_action_pressed(&"ui_cancel"):
		if _settings.visible:
			_close_settings()
		else:
			close()
		get_viewport().set_input_as_handled()


func open() -> void:
	is_open = true
	_root.visible = true
	_main.visible = true
	_settings.visible = false
	get_tree().paused = true
	_resume.grab_focus()


func close() -> void:
	is_open = false
	_root.visible = false
	get_tree().paused = false


func _open_settings() -> void:
	_main.visible = false
	_settings.visible = true
	_settings.focus_first()


func _close_settings() -> void:
	_settings.visible = false
	_main.visible = true
	_resume.grab_focus()
