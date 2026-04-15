extends Control

const TARGET_FPS: int = 60
## 28 * 18, 36 * 18 — must match board CELL_PX * grid in views.
const BOARD_VIEWPORT_SIZE: Vector2i = Vector2i(504, 648)
const SCREEN_BG_BASE: Color = Color(0.008, 0.015, 0.05, 1.0)
const SCREEN_BG_BRIGHT: Color = Color(0.018, 0.032, 0.08, 1.0)

const BG_NOISE_SHADER: Shader = preload("res://shaders/screen_bg_noise.gdshader")

@onready var _screen_bg: ColorRect = $ScreenBackground
@onready var _game_root: Node = $MarginPlayfield/AspectBoard/SubViewportContainer/SubViewport/GameRoot

var _screen_bg_noise_time_s: float = 0.0
var _screen_bg_shader_mat: ShaderMaterial

func _ready() -> void:
	_screen_bg_shader_mat = ShaderMaterial.new()
	_screen_bg_shader_mat.shader = BG_NOISE_SHADER
	_screen_bg_shader_mat.set_shader_parameter("base_color", SCREEN_BG_BASE)
	_screen_bg_shader_mat.set_shader_parameter("base_color_bottom", SCREEN_BG_BRIGHT)
	_screen_bg.material = _screen_bg_shader_mat
	_screen_bg.color = Color(1, 1, 1, 1)
	Engine.physics_ticks_per_second = TARGET_FPS
	var score_hud: Control = $CanvasLayerHud/ScoreLabel as Control
	var time_hud: Label = $CanvasLayerHud/TimeLabel as Label
	score_hud.add_to_group("game_score_hud")
	time_hud.add_to_group("game_time_hud")
	var _vp: SubViewport = $MarginPlayfield/AspectBoard/SubViewportContainer/SubViewport as SubViewport
	#vp.size = BOARD_VIEWPORT_SIZE
	# Match AspectRatioContainer to viewport (width / height); avoids float drift in .tscn.
	var ar: AspectRatioContainer = $MarginPlayfield/AspectBoard as AspectRatioContainer
	ar.ratio = float(BOARD_VIEWPORT_SIZE.x) / float(BOARD_VIEWPORT_SIZE.y)
	print("Waka-Lika Godot bootstrap OK.")
	# Prevent degenerate stretch transforms (affine_invert det==0) before layout has non-zero size.
	var svpc: SubViewportContainer = $MarginPlayfield/AspectBoard/SubViewportContainer as SubViewportContainer
	svpc.custom_minimum_size = Vector2(1, 1)

func _process(delta: float) -> void:
	if _screen_bg == null or _game_root == null or not _game_root.has_method("get_model"):
		return
	_screen_bg_noise_time_s += delta
	_screen_bg_shader_mat.set_shader_parameter("time", _screen_bg_noise_time_s * 0.4)
	# Width/height can be 0 for a frame during window/layout; avoid aspect=0 in the shader.
	var ar: float = _screen_bg.size.x / maxf(_screen_bg.size.y, 1.0)
	ar = clampf(ar, 0.05, 50.0)
	_screen_bg_shader_mat.set_shader_parameter("aspect", ar)
	var model: RefCounted = _game_root.call("get_model") as RefCounted
	var dark_c: Color = SCREEN_BG_BASE
	var bright_c: Color = SCREEN_BG_BRIGHT
	if model != null:
		var hk: float = float(model.get("hue_shift_amount"))
		dark_c = _hue_shift(SCREEN_BG_BASE, hk)
		bright_c = _hue_shift(SCREEN_BG_BRIGHT, hk)
	_screen_bg_shader_mat.set_shader_parameter("base_color", dark_c)
	_screen_bg_shader_mat.set_shader_parameter("base_color_bottom", bright_c)

func _hue_shift(c: Color, amount: float) -> Color:
	if amount <= 0.0:
		return c
	var h: float = fposmod(c.h + amount, 1.0)
	return Color.from_hsv(h, c.s, c.v, c.a)
