extends Node2D

const CELL_PX: float = 18.0
const TRAIL_MAX_SAMPLES: int = 24
const TRAIL_LIFE_S: float = 0.72
const TRAIL_MIN_SAMPLE_DIST_SQ: float = 0.22
const DIR_UP: int = 0
const DIR_DOWN: int = 1
const DIR_LEFT: int = 2
const DIR_RIGHT: int = 3
const CHOMP_FPS: float = 10.0

var _model: RefCounted = null
var _trail: Array = [] # Array[Dictionary]
var _pac_open_tex: Texture2D = null
var _pac_closed_tex: Texture2D = null
var _anim_time_s: float = 0.0
var _last_pac_pos: Vector2 = Vector2(-9999.0, -9999.0)
var _is_moving: bool = false
var _movement_cooldown_s: float = 0.0

func set_model(m: RefCounted) -> void:
	_model = m
	queue_redraw()

func _ready() -> void:
	_pac_open_tex = _load_svg_texture("res://assets/characters/pacman.svg", 128)
	_pac_closed_tex = _load_svg_texture("res://assets/characters/pacman-closed.svg", 128)

func _process(delta: float) -> void:
	if _model != null:
		_anim_time_s += delta
		var p_now: Vector2 = _model.get("pac_pos") as Vector2
		if _last_pac_pos.x < -9000.0:
			_last_pac_pos = p_now
		var moved: bool = _last_pac_pos.distance_squared_to(p_now) > 0.0009
		if moved:
			_movement_cooldown_s = 0.12
		else:
			_movement_cooldown_s = maxf(0.0, _movement_cooldown_s - delta)
		_is_moving = moved or _movement_cooldown_s > 0.0
		_last_pac_pos = p_now
		_decay_trail(delta)
		_push_trail_sample()
	queue_redraw()

func _draw() -> void:
	if _model == null:
		return
	var p: Vector2 = _model.get("pac_pos") as Vector2
	var dir: int = int(_model.get("pac_dir"))
	var w: int = 28
	var h: int = 36

	_draw_trail(w, h)
	for rp: Vector2 in _render_positions(p, w, h):
		var cx: float = rp.x * CELL_PX
		var cy: float = rp.y * CELL_PX
		if _pac_open_tex != null or _pac_closed_tex != null:
			var frame_open: bool = _is_moving and int(floor(_anim_time_s * CHOMP_FPS)) % 2 == 0
			var tex: Texture2D = _pac_open_tex if frame_open else _pac_closed_tex
			if tex == null:
				tex = _pac_open_tex if _pac_open_tex != null else _pac_closed_tex
			var rot: float = _dir_to_angle(dir)
			var sz: float = CELL_PX * 0.98
			draw_set_transform(Vector2(cx, cy), rot, Vector2.ONE)
			draw_texture_rect(tex, Rect2(-sz * 0.5, -sz * 0.5, sz, sz), false, Color(1, 1, 1, 1))
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		else:
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
	var dir: int = int(_model.get("pac_dir"))
	var frame_open: bool = _is_moving and int(floor(_anim_time_s * CHOMP_FPS)) % 2 == 0
	var rot: float = _dir_to_angle(dir)
	if not _trail.is_empty():
		var last: Dictionary = _trail[_trail.size() - 1] as Dictionary
		var lp: Vector2 = last.get("p", p) as Vector2
		if lp.distance_squared_to(p) < TRAIL_MIN_SAMPLE_DIST_SQ:
			return
	_trail.append({
		"p": p,
		"life_s": TRAIL_LIFE_S,
		"frame_open": frame_open,
		"rot": rot,
	})
	if _trail.size() > TRAIL_MAX_SAMPLES:
		_trail.remove_at(0)

func _draw_trail(w: int, h: int) -> void:
	for t_v: Variant in _trail:
		var t: Dictionary = t_v as Dictionary
		var p: Vector2 = t.get("p", Vector2.ZERO) as Vector2
		var life_k: float = clampf(float(t.get("life_s", 0.0)) / TRAIL_LIFE_S, 0.0, 1.0)
		var alpha: float = 0.22 * life_k
		var frame_open: bool = bool(t.get("frame_open", true))
		var rot: float = float(t.get("rot", 0.0))
		var tex: Texture2D = _pac_open_tex if frame_open else _pac_closed_tex
		if tex == null:
			tex = _pac_open_tex if _pac_open_tex != null else _pac_closed_tex
		for rp_v: Variant in _render_positions(p, w, h):
			var rp: Vector2 = rp_v as Vector2
			var cx: float = rp.x * CELL_PX
			var cy: float = rp.y * CELL_PX
			if tex != null:
				var sz: float = CELL_PX * (0.55 + 0.35 * life_k)
				draw_set_transform(Vector2(cx, cy), rot, Vector2.ONE)
				draw_texture_rect(tex, Rect2(-sz * 0.5, -sz * 0.5, sz, sz), false, Color(1.0, 1.0, 1.0, alpha))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			else:
				var radius: float = CELL_PX * (0.15 + 0.20 * life_k)
				draw_circle(Vector2(cx, cy), radius, Color(1.0, 0.85, 0.2, alpha))

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

func _load_svg_texture(res_path: String, raster_px: int) -> Texture2D:
	if not FileAccess.file_exists(res_path):
		push_error("SVG not found: %s" % res_path)
		return null
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(res_path)
	if bytes.size() == 0:
		push_error("SVG empty/unreadable: %s" % res_path)
		return null
	var img: Image = Image.new()
	var err: Error = img.load_svg_from_buffer(bytes, float(raster_px))
	if err != OK:
		push_error("SVG decode failed (%s): %s" % [str(err), res_path])
		return null
	return ImageTexture.create_from_image(img)

func _dir_to_angle(dir: int) -> float:
	if dir == DIR_RIGHT:
		return 0.0
	if dir == DIR_DOWN:
		return PI * 0.5
	if dir == DIR_LEFT:
		return PI
	if dir == DIR_UP:
		return -PI * 0.5
	return 0.0
