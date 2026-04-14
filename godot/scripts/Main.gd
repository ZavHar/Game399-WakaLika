extends Control

const TARGET_FPS: int = 60
## 28 * 18, 36 * 18 — must match board CELL_PX * grid in views.
const BOARD_VIEWPORT_SIZE: Vector2i = Vector2i(504, 648)
const SCREEN_BG_BASE: Color = Color(0.008, 0.015, 0.05, 1.0)

@onready var _screen_bg: ColorRect = $ScreenBackground
@onready var _game_root: Node = $MarginPlayfield/AspectBoard/SubViewportContainer/SubViewport/GameRoot

func _ready() -> void:
	Engine.physics_ticks_per_second = TARGET_FPS
	var score_hud: Control = $CanvasLayerHud/ScoreLabel as Control
	var time_hud: Label = $CanvasLayerHud/TimeLabel as Label
	score_hud.add_to_group("game_score_hud")
	time_hud.add_to_group("game_time_hud")
	var vp: SubViewport = $MarginPlayfield/AspectBoard/SubViewportContainer/SubViewport as SubViewport
	vp.size = BOARD_VIEWPORT_SIZE
	# Match AspectRatioContainer to viewport (width / height); avoids float drift in .tscn.
	var ar: AspectRatioContainer = $MarginPlayfield/AspectBoard as AspectRatioContainer
	ar.ratio = float(BOARD_VIEWPORT_SIZE.x) / float(BOARD_VIEWPORT_SIZE.y)
	print("Waka-Lika Godot bootstrap OK.")

func _process(_delta: float) -> void:
	if _screen_bg == null or _game_root == null or not _game_root.has_method("get_model"):
		return
	var model: RefCounted = _game_root.call("get_model") as RefCounted
	if model == null:
		_screen_bg.color = SCREEN_BG_BASE
		return
	var hk: float = float(model.get("hue_shift_amount"))
	_screen_bg.color = _hue_shift(SCREEN_BG_BASE, hk)

func _hue_shift(c: Color, amount: float) -> Color:
	if amount <= 0.0:
		return c
	var h: float = fposmod(c.h + amount, 1.0)
	return Color.from_hsv(h, c.s, c.v, c.a)
