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
	var p: Vector2 = _model.get("pac_pos") as Vector2
	var w: int = 28
	var h: int = 36

	for rp: Vector2 in _render_positions(p, w, h):
		var cx: float = rp.x * CELL_PX
		var cy: float = rp.y * CELL_PX
		draw_circle(Vector2(cx, cy), CELL_PX * 0.35, Color(1.0, 0.8, 0.1, 1.0))

func _render_positions(p: Vector2, w: int, h: int) -> Array:
	var out: Array = [p]
	var thr: float = 3.0
	if p.x <= thr:
		out.append(Vector2(p.x + float(w), p.y))
	elif p.x >= float(w) - thr:
		out.append(Vector2(p.x - float(w), p.y))
	if p.y <= thr:
		out.append(Vector2(p.x, p.y + float(h)))
	elif p.y >= float(h) - thr:
		out.append(Vector2(p.x, p.y - float(h)))
	return out
