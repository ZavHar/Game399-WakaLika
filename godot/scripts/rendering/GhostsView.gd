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
	var ghosts_v: Variant = _model.get("ghosts")
	if typeof(ghosts_v) != TYPE_ARRAY:
		return
	var ghosts: Array = ghosts_v as Array
	for g_v: Variant in ghosts:
		var g: RefCounted = g_v as RefCounted
		var from: Vector2i = g.get("anim_from") as Vector2i
		var to: Vector2i = g.get("anim_to") as Vector2i
		var t: float = float(g.get("anim_t"))
		var gv: Vector2 = GhostInterpolation.visual_center_fractional(from, to, t, 28, 36)
		var gx: float = gv.x
		var gy: float = gv.y
		var id: String = g.get("id") as String
		var base: Color = _visual_color_for_ghost(id, g)

		# gv is tile-space center (matches pac_pos convention).
		var render_positions: Array = _ghost_render_positions(Vector2(gx, gy), 28, 36)
		for rp: Variant in render_positions:
			var p: Vector2 = rp as Vector2
			var cx: float = p.x * CELL_PX
			var cy: float = p.y * CELL_PX
			draw_circle(Vector2(cx, cy), CELL_PX * 0.30, base)

func _color_for_id(id: String) -> Color:
	if id == "red":
		return Color(0.86, 0.15, 0.15, 1.0)
	if id == "pink":
		return Color(0.96, 0.45, 0.71, 1.0)
	if id == "blue":
		return Color(0.13, 0.83, 0.94, 1.0)
	if id == "orange":
		return Color(0.98, 0.57, 0.24, 1.0)
	return Color(0.6, 0.6, 0.6, 1.0)

func _visual_color_for_ghost(id: String, g: RefCounted) -> Color:
	if bool(g.get("is_incapacitated")):
		return Color(0.55, 0.55, 0.62, 0.85)
	# Approx web: fear blue + flashing white near end.
	var fear_ms: float = 0.0
	if _model != null:
		fear_ms = float(_model.get("fear_ms"))
	if fear_ms <= 0.0:
		return _color_for_id(id)

	var fear_blue: Color = Color(0.117, 0.227, 0.541, 1.0) # #1e3a8a
	if fear_ms > 2000.0:
		return fear_blue

	var flash_on: bool = int(floor(fear_ms / 150.0)) % 2 == 0
	return Color(1, 1, 1, 1) if flash_on else fear_blue

func _ghost_render_positions(p: Vector2, w: int, h: int) -> Array:
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
