extends Node2D

const CELL_PX: float = 18.0
const TRAIL_MAX_SAMPLES: int = 24
const TRAIL_LIFE_S: float = 0.72
const TRAIL_MIN_SAMPLE_DIST_SQ: float = 0.045

var _model: RefCounted = null
var _trail: Array = [] # Array[Dictionary]

func set_model(m: RefCounted) -> void:
	_model = m
	queue_redraw()

func _process(delta: float) -> void:
	if _model != null:
		_decay_trail(delta)
		_push_trail_sample()
	queue_redraw()

func _draw() -> void:
	if _model == null:
		return
	var p: Vector2 = _model.get("pac_pos") as Vector2
	var w: int = 28
	var h: int = 36

	_draw_trail(w, h)
	for rp: Vector2 in _render_positions(p, w, h):
		var cx: float = rp.x * CELL_PX
		var cy: float = rp.y * CELL_PX
		draw_circle(Vector2(cx, cy), CELL_PX * 0.35, Color(1.0, 0.8, 0.1, 1.0))

func _decay_trail(delta: float) -> void:
	var next: Array = []
	for t_v: Variant in _trail:
		var t: Dictionary = t_v as Dictionary
		var life_s: float = float(t.get("life_s", 0.0)) - delta
		if life_s <= 0.0:
			continue
		t["life_s"] = life_s
		next.append(t)
	_trail = next

func _push_trail_sample() -> void:
	var p: Vector2 = _model.get("pac_pos") as Vector2
	if not _trail.is_empty():
		var last: Dictionary = _trail[_trail.size() - 1] as Dictionary
		var lp: Vector2 = last.get("p", p) as Vector2
		if lp.distance_squared_to(p) < TRAIL_MIN_SAMPLE_DIST_SQ:
			return
	_trail.append({"p": p, "life_s": TRAIL_LIFE_S})
	if _trail.size() > TRAIL_MAX_SAMPLES:
		_trail.remove_at(0)

func _draw_trail(w: int, h: int) -> void:
	for t_v: Variant in _trail:
		var t: Dictionary = t_v as Dictionary
		var p: Vector2 = t.get("p", Vector2.ZERO) as Vector2
		var life_k: float = clampf(float(t.get("life_s", 0.0)) / TRAIL_LIFE_S, 0.0, 1.0)
		var alpha: float = 0.22 * life_k
		var radius: float = CELL_PX * (0.15 + 0.20 * life_k)
		for rp_v: Variant in _render_positions(p, w, h):
			var rp: Vector2 = rp_v as Vector2
			draw_circle(Vector2(rp.x * CELL_PX, rp.y * CELL_PX), radius, Color(1.0, 0.85, 0.2, alpha))

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
