class_name HUD
extends CanvasLayer
## In-game HUD: HP / stamina bars, solar energy discs, Ankh charges, Ka counter,
## boss bar with name, interaction prompt, area banner and notifications.

const HP_PIXELS_PER_POINT := 3.6

var player: Player
var _root: Control
var _hp: StatBar
var _stamina: StatBar
var _energy_box: HBoxContainer
var _suns: Array[DuatIcon] = []
var _ankh_box: HBoxContainer
var _ankhs: Array[DuatIcon] = []
var _ka_label: Label
var _ka_delta: Label
var _boss_root: Control
var _boss_bar: StatBar
var _boss_name: Label
var _boss: Node
var _prompt: PanelContainer
var _prompt_label: Label
var _banner: Label
var _banner_sub: Label
var _banner_back: TextureRect
var _notice: Label
var _ka_shown: int = 0
var _ka_tween: Tween


func _ready() -> void:
	layer = 10
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UIStyle.theme()
	add_child(_root)
	_build_vitals()
	_build_ka()
	_build_boss()
	_build_prompt()
	_build_banner()
	GameState.ka_changed.connect(_on_ka_changed)
	_ka_shown = GameState.ka
	_ka_label.text = str(_ka_shown)


func _build_vitals() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(48, 40)
	box.add_theme_constant_override(&"separation", 10)
	_root.add_child(box)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 14)
	box.add_child(row)
	var emblem := DuatIcon.new(DuatIcon.Kind.EYE, 44.0)
	row.add_child(emblem)
	var bars := VBoxContainer.new()
	bars.add_theme_constant_override(&"separation", 8)
	row.add_child(bars)
	_hp = StatBar.new()
	_hp.custom_minimum_size = Vector2(360, 20)
	bars.add_child(_hp)
	_stamina = StatBar.new()
	_stamina.custom_minimum_size = Vector2(300, 11)
	_stamina.fill_color = Color(0.28, 0.75, 0.62)
	_stamina.lag_color = Color(0.85, 0.95, 0.8, 0.6)
	_stamina.frame_color = UIStyle.GOLD_DIM
	bars.add_child(_stamina)
	var icons := HBoxContainer.new()
	icons.add_theme_constant_override(&"separation", 24)
	box.add_child(icons)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(44, 0)
	icons.add_child(spacer)
	_ankh_box = HBoxContainer.new()
	_ankh_box.add_theme_constant_override(&"separation", 2)
	icons.add_child(_ankh_box)
	_energy_box = HBoxContainer.new()
	_energy_box.add_theme_constant_override(&"separation", 2)
	icons.add_child(_energy_box)


func _build_ka() -> void:
	var plate := PanelContainer.new()
	var sb := UIStyle.lapis_box(UIStyle.GOLD_DIM, 2, 3)
	sb.set_content_margin_all(8)
	sb.content_margin_left = 16
	sb.content_margin_right = 18
	plate.add_theme_stylebox_override(&"panel", sb)
	plate.anchor_left = 1.0
	plate.anchor_right = 1.0
	plate.anchor_top = 1.0
	plate.anchor_bottom = 1.0
	plate.offset_right = -48
	plate.offset_bottom = -40
	plate.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	plate.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_root.add_child(plate)
	var box := HBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_END
	box.add_theme_constant_override(&"separation", 10)
	plate.add_child(box)
	_ka_delta = UIStyle.label("", 22, UIStyle.TURQUOISE, true)
	box.add_child(_ka_delta)
	var icon := DuatIcon.new(DuatIcon.Kind.KA, 40.0)
	icon.color = UIStyle.TURQUOISE
	box.add_child(icon)
	_ka_label = UIStyle.label("0", 38, UIStyle.GOLD, true)
	box.add_child(_ka_label)


func _build_boss() -> void:
	_boss_root = VBoxContainer.new()
	_boss_root.anchor_left = 0.5
	_boss_root.anchor_right = 0.5
	_boss_root.anchor_top = 1.0
	_boss_root.anchor_bottom = 1.0
	_boss_root.offset_left = -480
	_boss_root.offset_right = 480
	_boss_root.offset_top = -150
	_boss_root.offset_bottom = -90
	_boss_root.add_theme_constant_override(&"separation", 6)
	_boss_root.visible = false
	_root.add_child(_boss_root)
	_boss_name = UIStyle.label("", 28, UIStyle.GOLD, true)
	_boss_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_boss_root.add_child(_boss_name)
	_boss_bar = StatBar.new()
	_boss_bar.custom_minimum_size = Vector2(960, 18)
	_boss_bar.fill_color = Color(0.62, 0.1, 0.12)
	_boss_root.add_child(_boss_bar)


func _build_prompt() -> void:
	_prompt = PanelContainer.new()
	_prompt.add_theme_stylebox_override(&"panel", UIStyle.lapis_box(UIStyle.GOLD, 2, 3))
	_prompt.anchor_left = 0.5
	_prompt.anchor_right = 0.5
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_top = -250
	_prompt.offset_bottom = -200
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.visible = false
	_root.add_child(_prompt)
	_prompt_label = UIStyle.label("", 24, UIStyle.PAPYRUS)
	_prompt.add_child(_prompt_label)


func _build_banner() -> void:
	_banner_back = TextureRect.new()
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.5, 1.0])
	grad.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0.02, 0.03, 0.08, 0.7), Color(0, 0, 0, 0)])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.width = 256
	gt.height = 8
	_banner_back.texture = gt
	_banner_back.stretch_mode = TextureRect.STRETCH_SCALE
	_banner_back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_banner_back.anchor_left = 0.15
	_banner_back.anchor_right = 0.85
	_banner_back.offset_top = 140
	_banner_back.offset_bottom = 270
	_banner_back.modulate.a = 0.0
	_banner_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_banner_back)
	var box := VBoxContainer.new()
	box.anchor_left = 0.0
	box.anchor_right = 1.0
	box.offset_top = 150
	box.offset_bottom = 260
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(box)
	_banner = UIStyle.label("", 52, UIStyle.GOLD, true)
	_banner.add_theme_constant_override(&"outline_size", 10)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.modulate.a = 0.0
	box.add_child(_banner)
	_banner_sub = UIStyle.label("", 24, UIStyle.PAPYRUS)
	_banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_sub.modulate.a = 0.0
	box.add_child(_banner_sub)
	_notice = UIStyle.label("", 28, UIStyle.TURQUOISE, true)
	_notice.add_theme_constant_override(&"outline_size", 8)
	_notice.anchor_left = 0.0
	_notice.anchor_right = 1.0
	_notice.anchor_top = 1.0
	_notice.anchor_bottom = 1.0
	_notice.offset_top = -330
	_notice.offset_bottom = -290
	_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_notice.modulate.a = 0.0
	_root.add_child(_notice)


func bind_player(p: Player) -> void:
	player = p
	player.interact_target_changed.connect(_on_interact_changed)


func _process(_delta: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var max_hp := player.health.max_health
	_hp.custom_minimum_size.x = clampf(max_hp * HP_PIXELS_PER_POINT, 300.0, 820.0)
	_hp.set_values(player.health.current, max_hp)
	_stamina.visible = player.stats.stamina_enabled
	_stamina.custom_minimum_size.x = player.max_stamina * 3.0
	_stamina.set_values(maxf(player.stamina, 0.0), player.max_stamina)
	_sync_icons(_suns, _energy_box, player.stats.max_energy, DuatIcon.Kind.SUN, UIStyle.GOLD)
	for i in _suns.size():
		_suns[i].set_fill(clampf(player.energy - float(i), 0.0, 1.0))
	_sync_icons(_ankhs, _ankh_box, GameState.max_ankh(), DuatIcon.Kind.ANKH, UIStyle.TURQUOISE)
	for i in _ankhs.size():
		_ankhs[i].set_fill(1.0 if i < player.ankh else 0.0)
	if _boss_root.visible and _boss != null and is_instance_valid(_boss):
		var hc := _boss.get("health") as HealthComponent
		if hc != null:
			_boss_bar.set_values(hc.current, hc.max_health)
	if _prompt.visible and player.interactable != null and is_instance_valid(player.interactable):
		_prompt_label.text = _prompt_text(player.interactable)


func _sync_icons(list: Array[DuatIcon], box: HBoxContainer, count: int, kind: DuatIcon.Kind, color: Color) -> void:
	while list.size() < count:
		var icon := DuatIcon.new(kind, 34.0)
		icon.color = color
		box.add_child(icon)
		list.append(icon)
	while list.size() > count:
		var last: DuatIcon = list.pop_back()
		last.queue_free()


func _prompt_text(it: Node) -> String:
	var glyph := UIStyle.action_glyph(&"interact", player.input.using_gamepad)
	return "[%s]  %s" % [glyph, String(it.call(&"get_prompt"))]


func _on_interact_changed(it: Node) -> void:
	_prompt.visible = it != null
	if it != null:
		_prompt_label.text = _prompt_text(it)
		_prompt.reset_size()


func _on_ka_changed(amount: int) -> void:
	var diff := amount - _ka_shown
	if _ka_tween != null and _ka_tween.is_valid():
		_ka_tween.kill()
	if diff > 0:
		_ka_delta.text = "+%d" % diff
		_ka_delta.modulate.a = 1.0
	var count := func(v: float) -> void:
		_ka_shown = int(v)
		_ka_label.text = str(_ka_shown)
	_ka_tween = create_tween()
	_ka_tween.tween_method(count, float(_ka_shown), float(amount), 0.6)
	_ka_tween.parallel().tween_property(_ka_delta, "modulate:a", 0.0, 1.2).set_delay(0.8)


func show_boss(boss: Node, boss_name: String) -> void:
	_boss = boss
	_boss_name.text = boss_name.to_upper()
	_boss_root.visible = true
	_boss_root.modulate.a = 0.0
	create_tween().tween_property(_boss_root, "modulate:a", 1.0, 1.0)


func hide_boss() -> void:
	if not _boss_root.visible:
		return
	var tw := create_tween()
	tw.tween_property(_boss_root, "modulate:a", 0.0, 1.0)
	tw.tween_callback(func() -> void: _boss_root.visible = false)


func show_banner(title: String, subtitle: String = "", hold: float = 2.2) -> void:
	_banner.text = title.to_upper()
	_banner_sub.text = subtitle
	var tw := create_tween()
	tw.tween_property(_banner, "modulate:a", 1.0, 0.8)
	tw.parallel().tween_property(_banner_back, "modulate:a", 1.0, 0.8)
	tw.parallel().tween_property(_banner_sub, "modulate:a", 1.0, 0.8).set_delay(0.3)
	tw.tween_interval(hold)
	tw.tween_property(_banner, "modulate:a", 0.0, 1.0)
	tw.parallel().tween_property(_banner_back, "modulate:a", 0.0, 1.0)
	tw.parallel().tween_property(_banner_sub, "modulate:a", 0.0, 1.0)


func notify(text: String, color: Color = UIStyle.TURQUOISE) -> void:
	_notice.text = text
	_notice.add_theme_color_override(&"font_color", color)
	var tw := create_tween()
	tw.tween_property(_notice, "modulate:a", 1.0, 0.3)
	tw.tween_interval(2.4)
	tw.tween_property(_notice, "modulate:a", 0.0, 0.8)


func set_visible_hud(v: bool) -> void:
	_root.visible = v
