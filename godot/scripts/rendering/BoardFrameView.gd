extends Node2D

const BOARD_W_PX: float = 504.0
const BOARD_H_PX: float = 648.0
const FRAME_THICKNESS: float = 4.0
const FRAME_COLOR: Color = Color(0.30, 0.65, 1.0, 0.95)

var _model: RefCounted = null

func set_model(m: RefCounted) -> void:
	_model = m
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var r: Rect2 = Rect2(0.0, 0.0, BOARD_W_PX, BOARD_H_PX)
	var c: Color = FRAME_COLOR
	if _model != null:
		var hk: float = float(_model.get("hue_shift_amount"))
		if hk > 0.0:
			c = _hue_shift(c, hk)
	draw_rect(r, c, false, FRAME_THICKNESS)

func _hue_shift(c: Color, amount: float) -> Color:
	var h: float = fposmod(c.h + amount, 1.0)
	return Color.from_hsv(h, c.s, c.v, c.a)
