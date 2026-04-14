extends Node2D

const CELL_PX: float = 18.0
const GHOST_TRAIL_MAX_SAMPLES: int = 20
const GHOST_TRAIL_LIFE_S: float = 0.70
const GHOST_TRAIL_MIN_SAMPLE_DIST_SQ: float = 0.05

var _model: RefCounted = null
var _trail_by_id: Dictionary = {}

func set_model(m: RefCounted) -> void:
	_model = m
	queue_redraw()

func _process(delta: float) -> void:
	_decay_ghost_trails(delta)
	queue_redraw()

func _draw() -> void:
	if _model == null:
		return
	var ghosts_v: Variant = _model.get("ghosts")
	if typeof(ghosts_v) != TYPE_ARRAY:
		return
	var ghosts: Array = ghosts_v as Array

	# Pass 1: update trail samples and draw all trails first (keeps trails behind entities).
	for g_v: Variant in ghosts:
		var g_trail: RefCounted = g_v as RefCounted
		var from_t: Vector2i = g_trail.get("anim_from") as Vector2i
		var to_t: Vector2i = g_trail.get("anim_to") as Vector2i
		var interp_t: float = float(g_trail.get("anim_t"))
		var gv_t: Vector2 = GhostInterpolation.visual_center_fractional(from_t, to_t, interp_t, 28, 36)
		var id_t: String = g_trail.get("id") as String
		var phase_t: String = str(g_trail.get("incapacitated_phase"))
		_push_ghost_trail(id_t, Vector2(gv_t.x, gv_t.y))
		_draw_ghost_trail(id_t, phase_t)

	# Pass 2: draw ghost bodies/effects on top of trails.
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
		var phase: String = str(g.get("incapacitated_phase"))

		# gv is tile-space center (matches pac_pos convention).
		var render_positions: Array = _ghost_render_positions(Vector2(gx, gy), 28, 36)
		for rp: Variant in render_positions:
			var p: Vector2 = rp as Vector2
			var cx: float = p.x * CELL_PX
			var cy: float = p.y * CELL_PX
			var center: Vector2 = Vector2(cx, cy)
			draw_circle(center, CELL_PX * 0.30, base)
			if bool(g.get("is_incapacitated")):
				_draw_incap_ghost_fx(center, phase)

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

func _push_ghost_trail(id: String, p: Vector2) -> void:
	var arr: Array = _trail_by_id.get(id, []) as Array
	if not arr.is_empty():
		var last: Dictionary = arr[arr.size() - 1] as Dictionary
		var lp: Vector2 = last.get("p", p) as Vector2
		if lp.distance_squared_to(p) < GHOST_TRAIL_MIN_SAMPLE_DIST_SQ:
			_trail_by_id[id] = arr
			return
	arr.append({"p": p, "life_s": GHOST_TRAIL_LIFE_S})
	if arr.size() > GHOST_TRAIL_MAX_SAMPLES:
		arr.remove_at(0)
	_trail_by_id[id] = arr

func _decay_ghost_trails(delta: float) -> void:
	var keys: Array = _trail_by_id.keys()
	for k_v: Variant in keys:
		var k: String = str(k_v)
		var arr: Array = _trail_by_id.get(k, []) as Array
		var next: Array = []
		for t_v: Variant in arr:
			var t: Dictionary = t_v as Dictionary
			var life_s: float = float(t.get("life_s", 0.0)) - delta
			if life_s <= 0.0:
				continue
			t["life_s"] = life_s
			next.append(t)
		_trail_by_id[k] = next

func _draw_ghost_trail(id: String, phase: String) -> void:
	var arr: Array = _trail_by_id.get(id, []) as Array
	var n: int = arr.size()
	if n <= 1:
		return
	for i: int in range(n - 1, -1, -1):
		var t: Dictionary = arr[i] as Dictionary
		var p: Vector2 = t.get("p", Vector2.ZERO) as Vector2
		var life_k: float = clampf(float(t.get("life_s", 0.0)) / GHOST_TRAIL_LIFE_S, 0.0, 1.0)
		var k: float = maxf(life_k, float(i + 1) / float(n) * 0.6)
		var alpha: float = (0.08 + 0.08 * k) * (1.2 if phase == "return_to_house" else 1.0)
		var col: Color = Color(0.95, 0.96, 1.0, alpha)
		for rp_v: Variant in _ghost_render_positions(p, 28, 36):
			var rp: Vector2 = rp_v as Vector2
			draw_circle(Vector2(rp.x * CELL_PX, rp.y * CELL_PX), CELL_PX * (0.12 + 0.1 * k), col)

func _draw_incap_ghost_fx(center: Vector2, phase: String) -> void:
	var pulse: float = 0.5
	if _model != null:
		var t: float = float(_model.get("time_remaining_s"))
		pulse = 0.5 + 0.5 * sin(t * TAU * 1.7)
	var ring_a: float = 0.22 + 0.18 * pulse
	if phase == "waiting_in_house":
		ring_a *= 0.8
	draw_arc(center, CELL_PX * 0.37, 0.0, TAU, 22, Color(0.95, 0.97, 1.0, ring_a), 1.5, true)
