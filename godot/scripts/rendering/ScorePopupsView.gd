extends Node2D

const CELL_PX: float = 18.0

var _model: RefCounted = null

func set_model(m: RefCounted) -> void:
	_model = m
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if _model == null:
		return
	var popups_v: Variant = _model.get("juice_popups")
	if typeof(popups_v) != TYPE_ARRAY:
		return
	var popups: Array = popups_v as Array
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return
	for p_v: Variant in popups:
		var p: Dictionary = p_v as Dictionary
		var pos: Vector2 = p.get("pos", Vector2.ZERO) as Vector2
		var text: String = str(p.get("text", ""))
		var color: Color = p.get("color", Color.WHITE) as Color
		var ms: float = float(p.get("ms", 0.0))
		var total_ms: float = maxf(1.0, float(p.get("total_ms", 1.0)))
		var scale_k: float = float(p.get("scale", 1.0))
		var life: float = clampf(ms / total_ms, 0.0, 1.0)
		var rise_px: float = (1.0 - life) * 24.0
		var alpha: float = pow(life, 0.8)
		var size: int = int(round(15.0 * scale_k))
		var text_w: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
		var draw_pos: Vector2 = Vector2(pos.x * CELL_PX - text_w * 0.5, pos.y * CELL_PX - rise_px)
		draw_string(font, draw_pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, Color(color.r, color.g, color.b, alpha))
