extends Node2D

const BOARD_W_PX: float = 504.0
const BOARD_H_PX: float = 648.0

const BG_TOP: Color = Color(0.015, 0.035, 0.12, 1.0)
const BG_BOTTOM: Color = Color(0.01, 0.02, 0.08, 1.0)

var _model: RefCounted = null
var _noise_rect: ColorRect
var _mat: ShaderMaterial
var _noise_time_s: float = 0.0

func _ready() -> void:
	var sh: Shader = preload("res://shaders/screen_bg_noise.gdshader")
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_mat.set_shader_parameter("aspect", BOARD_W_PX / BOARD_H_PX)
	_mat.set_shader_parameter("base_color", BG_BOTTOM)
	_mat.set_shader_parameter("base_color_bottom", BG_TOP)
	_noise_rect = ColorRect.new()
	_noise_rect.position = Vector2.ZERO
	_noise_rect.size = Vector2(BOARD_W_PX, BOARD_H_PX)
	_noise_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_noise_rect.color = Color(1, 1, 1, 1)
	_noise_rect.material = _mat
	add_child(_noise_rect)

func set_model(m: RefCounted) -> void:
	_model = m

func _process(delta: float) -> void:
	_noise_time_s += delta
	if _mat != null:
		_mat.set_shader_parameter("time", _noise_time_s)
		var c_top: Color = BG_TOP
		var c_bottom: Color = BG_BOTTOM
		if _model != null:
			var hk: float = float(_model.get("hue_shift_amount"))
			if hk > 0.0:
				c_top = _hue_shift(BG_TOP, hk)
				c_bottom = _hue_shift(BG_BOTTOM, hk)
		_mat.set_shader_parameter("base_color", c_bottom)
		_mat.set_shader_parameter("base_color_bottom", c_top)

func _hue_shift(c: Color, amount: float) -> Color:
	var h: float = fposmod(c.h + amount, 1.0)
	return Color.from_hsv(h, c.s, c.v, c.a)
