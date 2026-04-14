extends Node2D

const CELL_PX: float = 18.0

var _model: RefCounted = null
# find_path_bfs is expensive; cache per ghost until tile goal inputs change.
var _path_cache: Dictionary = {} # int -> { "k": int, "path": Array }

func set_model(m: RefCounted) -> void:
	_model = m
	_path_cache.clear()
	queue_redraw()

func _path_cache_key(pos: Vector2i, dest: Vector2i, dir: int) -> int:
	var packed: PackedInt32Array = PackedInt32Array([pos.x, pos.y, dest.x, dest.y, dir])
	return hash(packed)

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if _model == null:
		return
	var ghosts_v: Variant = _model.get("ghosts")
	if typeof(ghosts_v) != TYPE_ARRAY:
		return
	var ghosts: Array = ghosts_v as Array
	for gi: int in range(ghosts.size()):
		var g: RefCounted = ghosts[gi] as RefCounted
		var pos: Vector2i = g.get("pos") as Vector2i
		var dest: Vector2i = g.get("dest") as Vector2i
		var dir: int = int(g.get("dir"))
		var id: String = g.get("id") as String

		var ck: int = _path_cache_key(pos, dest, dir)
		var path: Array = []
		var entry: Variant = _path_cache.get(gi)
		if entry != null:
			var ed: Dictionary = entry as Dictionary
			if int(ed.get("k", -1)) == ck:
				path = ed.get("path") as Array
		if path.is_empty():
			var path_v: Variant = _model.call("find_path_bfs", pos, dest, dir)
			if typeof(path_v) != TYPE_ARRAY:
				continue
			path = path_v as Array
			_path_cache[gi] = {"k": ck, "path": path}

		if path.size() < 2:
			continue

		var c: Color = _color_for_id(id)
		c.a = 0.35
		var start_v: Vector2 = _ghost_render_pos(g)
		var start: Vector2 = Vector2((start_v.x + 0.5) * CELL_PX, (start_v.y + 0.5) * CELL_PX)

		_draw_path_with_warp(path, start, c)

func _ghost_render_pos(g: RefCounted) -> Vector2:
	var from: Vector2i = g.get("anim_from") as Vector2i
	var to: Vector2i = g.get("anim_to") as Vector2i
	var t: float = float(g.get("anim_t"))
	return Vector2(lerp(float(from.x), float(to.x), t), lerp(float(from.y), float(to.y), t))

func _draw_path_with_warp(path: Array, start_px: Vector2, c: Color) -> void:
	var bw: int = 28
	var bh: int = 36
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(start_px)

	var prev: Vector2i = path[0] as Vector2i
	for i: int in range(1, path.size()):
		var cur: Vector2i = path[i] as Vector2i
		var warp_x_right: bool = prev.y == cur.y and prev.x == bw - 1 and cur.x == 0
		var warp_x_left: bool = prev.y == cur.y and prev.x == 0 and cur.x == bw - 1
		var warp_y_down: bool = prev.x == cur.x and prev.y == bh - 1 and cur.y == 0
		var warp_y_up: bool = prev.x == cur.x and prev.y == 0 and cur.y == bh - 1

		var cur_px: Vector2 = Vector2((float(cur.x) + 0.5) * CELL_PX, (float(cur.y) + 0.5) * CELL_PX)

		if warp_x_right:
			# leaving right edge then enter from left off-board
			pts.append(Vector2(float(bw) * CELL_PX + CELL_PX * 0.5, (float(prev.y) + 0.5) * CELL_PX))
			draw_polyline(pts, c, 2.0, false)
			pts = PackedVector2Array()
			pts.append(Vector2(-CELL_PX * 0.5, (float(cur.y) + 0.5) * CELL_PX))
			pts.append(cur_px)
		elif warp_x_left:
			pts.append(Vector2(-CELL_PX * 0.5, (float(prev.y) + 0.5) * CELL_PX))
			draw_polyline(pts, c, 2.0, false)
			pts = PackedVector2Array()
			pts.append(Vector2(float(bw) * CELL_PX + CELL_PX * 0.5, (float(cur.y) + 0.5) * CELL_PX))
			pts.append(cur_px)
		elif warp_y_down:
			pts.append(Vector2((float(prev.x) + 0.5) * CELL_PX, float(bh) * CELL_PX + CELL_PX * 0.5))
			draw_polyline(pts, c, 2.0, false)
			pts = PackedVector2Array()
			pts.append(Vector2((float(cur.x) + 0.5) * CELL_PX, -CELL_PX * 0.5))
			pts.append(cur_px)
		elif warp_y_up:
			pts.append(Vector2((float(prev.x) + 0.5) * CELL_PX, -CELL_PX * 0.5))
			draw_polyline(pts, c, 2.0, false)
			pts = PackedVector2Array()
			pts.append(Vector2((float(cur.x) + 0.5) * CELL_PX, float(bh) * CELL_PX + CELL_PX * 0.5))
			pts.append(cur_px)
		else:
			pts.append(cur_px)

		prev = cur

	if pts.size() >= 2:
		draw_polyline(pts, c, 2.0, false)

func _to_points(path: Array) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	for v: Variant in path:
		var p: Vector2i = v as Vector2i
		var cx: float = (float(p.x) + 0.5) * CELL_PX
		var cy: float = (float(p.y) + 0.5) * CELL_PX
		pts.append(Vector2(cx, cy))
	return pts

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
