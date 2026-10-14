class_name ScreenFX
extends CanvasLayer
## Post-process overlay (vignette, grade, grain, hit aberration, low-health pulse).

const SHADER := preload("res://assets/shaders/screen_fx.gdshader")

var player: Player
var _rect: ColorRect
var _mat: ShaderMaterial
var _hurt: float = 0.0
var _aberration: float = 0.0


func _ready() -> void:
	layer = 5
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	_rect.material = _mat
	add_child(_rect)


func bind_player(p: Player) -> void:
	player = p
	player.damaged.connect(_on_player_damaged)


func _on_player_damaged(hit: HitInfo) -> void:
	if hit.is_dot:
		_hurt = maxf(_hurt, 0.25)
		return
	_hurt = 1.0
	_aberration = 0.012 if hit.is_heavy else 0.007


## Short chromatic punch for big impacts (boss slams, heavy charge).
func punch(amount: float = 0.008) -> void:
	_aberration = maxf(_aberration, amount)


func set_grade(shadows: Color, highlights: Color) -> void:
	_mat.set_shader_parameter(&"grade_shadows", shadows)
	_mat.set_shader_parameter(&"grade_highlights", highlights)


func _process(delta: float) -> void:
	_hurt = maxf(0.0, _hurt - delta * 2.5)
	_aberration = maxf(0.0, _aberration - delta * 0.04)
	var low := 0.0
	var desat := 0.0
	if player != null and is_instance_valid(player):
		var r := player.health.ratio()
		low = clampf((0.3 - r) / 0.3, 0.0, 1.0)
		if player.is_dead:
			desat = 0.65
	_mat.set_shader_parameter(&"low_health", low)
	_mat.set_shader_parameter(&"hurt", _hurt)
	_mat.set_shader_parameter(&"aberration", _aberration)
	_mat.set_shader_parameter(&"desaturate", desat)
