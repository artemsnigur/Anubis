class_name LevelUpMenu
extends CanvasLayer
## Altar of Osiris menu: spend Ka on Vitality / Strength / Spirit.

signal closed

const STAT_INFO := {
	&"vitality": ["Vitality", "Maximum health"],
	&"strength": ["Strength", "Khopesh damage"],
	&"spirit": ["Spirit", "Solar energy gain and Eye of Ra damage"],
}

var _root: Control
var _panel: PanelContainer
var _ka: Label
var _level: Label
var _cost: Label
var _rows: Dictionary = {}
var _descs: Dictionary = {}
var _buttons: Array[Button] = []
var _leave: Button
var is_open: bool = false


func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_ALWAYS
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIStyle.theme()
	_root.visible = false
	add_child(_root)
	var dim := ColorRect.new()
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.color = Color(0, 0, 0, 0.45)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	_panel = PanelContainer.new()
	_panel.add_theme_stylebox_override(&"panel", UIStyle.papyrus_box())
	_panel.custom_minimum_size = Vector2(760, 0)
	center.add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	_panel.add_child(box)
	var title := _ink("ALTAR OF OSIRIS", 44, true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)
	var sub := _ink("You rest. Health and Ankh charges are restored - and the dead of the Duat rise again.", 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(sub)
	var info := HBoxContainer.new()
	info.alignment = BoxContainer.ALIGNMENT_CENTER
	info.add_theme_constant_override(&"separation", 40)
	box.add_child(info)
	_ka = _ink("", 28, true)
	_level = _ink("", 28, true)
	_cost = _ink("", 28, true)
	info.add_child(_ka)
	info.add_child(_level)
	info.add_child(_cost)
	for stat: StringName in GameState.STATS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override(&"separation", 18)
		box.add_child(row)
		var names: Array = STAT_INFO[stat]
		var n := _ink(String(names[0]), 30, true)
		n.custom_minimum_size = Vector2(170, 0)
		row.add_child(n)
		var d := _ink(String(names[1]), 20)
		d.custom_minimum_size = Vector2(330, 0)
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(d)
		_descs[stat] = d
		var lv := _ink("", 28, true)
		lv.custom_minimum_size = Vector2(70, 0)
		row.add_child(lv)
		var b := UIStyle.button("+", _on_level.bind(stat))
		b.custom_minimum_size = Vector2(70, 0)
		row.add_child(b)
		_buttons.append(b)
		_rows[stat] = lv
	_leave = UIStyle.button("Rise and leave", close)
	box.add_child(_leave)


func _ink(text: String, size: int, heading: bool = false) -> Label:
	var l := UIStyle.label(text, size, UIStyle.INK, heading)
	l.add_theme_constant_override(&"outline_size", 0)
	return l


func open() -> void:
	is_open = true
	_root.visible = true
	_refresh()
	_buttons[0].grab_focus()
	_panel.scale = Vector2(0.95, 0.95)
	_panel.pivot_offset = _panel.size * 0.5
	create_tween().tween_property(_panel, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func close() -> void:
	if not is_open:
		return
	is_open = false
	_root.visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if is_open and (event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause")):
		get_viewport().set_input_as_handled()
		close()


func _on_level(stat: StringName) -> void:
	if GameState.get_level(stat) >= GameState.leveling.max_level_per_stat:
		AudioManager.play_event(&"ui_deny")
		return
	if GameState.level_up(stat):
		AudioManager.play_event(&"level_up")
		var p := get_tree().get_first_node_in_group(&"player") as Player
		if p != null:
			p.refresh_stats(true)
			Vfx.motes(p.global_position + Vector3.UP, 20)
		SaveSystem.save_game()
	else:
		AudioManager.play_event(&"ui_deny")
	_refresh()


func _refresh() -> void:
	_ka.text = "Ka: %d" % GameState.ka
	_level.text = "Level %d" % GameState.total_level()
	_cost.text = "Next: %d Ka" % GameState.level_cost()
	_cost.add_theme_color_override(&"font_color", UIStyle.INK if GameState.can_level_up() else Color(0.55, 0.15, 0.1))
	var lc := GameState.leveling
	for stat: StringName in _rows:
		var names: Array = STAT_INFO[stat]
		var extra := ""
		match stat:
			&"vitality":
				extra = "%d HP  ->  %d" % [int(GameState.max_hp()), int(GameState.max_hp() + lc.hp_per_vitality)]
			&"strength":
				extra = "damage x%.2f  ->  x%.2f" % [GameState.melee_multiplier(), GameState.melee_multiplier() + lc.melee_bonus_per_strength]
			&"spirit":
				extra = "x%.2f  ->  x%.2f" % [GameState.spirit_damage_multiplier(), GameState.spirit_damage_multiplier() + lc.ranged_bonus_per_spirit]
		(_rows[stat] as Label).text = str(GameState.get_level(stat))
		(_descs[stat] as Label).text = "%s\n%s" % [names[1], extra]
	for b in _buttons:
		b.disabled = not GameState.can_level_up()
	if not GameState.can_level_up() and (get_viewport().gui_get_focus_owner() == null or get_viewport().gui_get_focus_owner() is Button and (get_viewport().gui_get_focus_owner() as Button).disabled):
		_leave.grab_focus()
