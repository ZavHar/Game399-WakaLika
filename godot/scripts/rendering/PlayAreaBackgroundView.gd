extends Node2D

const BOARD_W_PX: float = 504.0
const BOARD_H_PX: float = 648.0

const BG_TOP: Color = Color(0.015, 0.035, 0.12, 1.0)
const BG_BOTTOM: Color = Color(0.01, 0.02, 0.08, 1.0)

var _model: RefCounted = null

func set_model(m: RefCounted) -> void:
	_model = m
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	var c_top: Color = BG_TOP
	var c_bottom: Color = BG_BOTTOM
	if _model != null:
		var hk: float = float(_model.get("hue_shift_amount"))
		if hk > 0.0:
			c_top = _hue_shift(c_top, hk)
			c_bottom = _hue_shift(c_bottom, hk)
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(0.0, 0.0),
		Vector2(BOARD_W_PX, 0.0),
		Vector2(BOARD_W_PX, BOARD_H_PX),
		Vector2(0.0, BOARD_H_PX),
	])
	var cols: PackedColorArray = PackedColorArray([c_top, c_top, c_bottom, c_bottom])
	draw_polygon(pts, cols)

func _hue_shift(c: Color, amount: float) -> Color:
	var h: float = fposmod(c.h + amount, 1.0)
	return Color.from_hsv(h, c.s, c.v, c.a)
