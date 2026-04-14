extends Node2D

const CELL_PX: float = 18.0

var _level_grids: LevelGrids
var _board: BoardModel
var _active_layout_name: String = ""
var _model: RefCounted = null

var _wall_tex: Texture2D = null
var _pellet_tex: Texture2D = null
var _exit_tex: Texture2D = null

# Web parity constants (see web `renderCanvas.ts`)
const WALL_TINT: Color = Color(0.0, 48.0 / 255.0, 206.0 / 255.0, 0.65)
const SIDE_CLEAR_DARK_MAX: float = 0.45
const SIDE_CLEAR_SEAM_FALLOFF_TILES: float = 3.0

func load_default_layout() -> void:
	_level_grids = LevelGrids.load_from_path("res://assets/data/levelGrids.json")
	var names: PackedStringArray = _level_grids.get_layout_names_sorted()
	if names.size() == 0:
		push_error("No layouts found in levelGrids.json")
		return

	_active_layout_name = names[0]
	var left_half: Array = _level_grids.get_layout(_active_layout_name)
	_board = BoardModel.from_left_half(left_half)

	print("Loaded layouts: %d (active: %s)" % [names.size(), _active_layout_name])
	_wall_tex = _load_png_texture("res://assets/tiles/maze-wall-atlas.png")
	_pellet_tex = _load_svg_texture("res://assets/tiles/pellet-white.svg", 64)
	_exit_tex = _load_svg_texture("res://assets/tiles/exit-white.svg", 64)
	queue_redraw()

func get_board_model() -> BoardModel:
	return _board

func set_model(m: RefCounted) -> void:
	_model = m
	queue_redraw()

func _process(_delta: float) -> void:
	# Keep visual pellet state in sync with the simulation.
	if _model != null:
		queue_redraw()

func _draw() -> void:
	if _board == null:
		return

	var w: int = BoardModel.FULL_W
	var h: int = BoardModel.H
	var cell: Vector2 = Vector2(CELL_PX, CELL_PX)
	for y: int in range(h):
		for x: int in range(w):
			var t: int = _board.tile_at(x, y)
			var p: Vector2 = Vector2(float(x) * CELL_PX, float(y) * CELL_PX)
			if t == Tile.Id.WALL:
				_draw_wall_at(x, y, p, cell)
			else:
				if t == Tile.Id.EXIT:
					_draw_exit_at(p, cell)
				elif t == Tile.Id.PELLET or t == Tile.Id.POWER_PELLET:
					_draw_pellet_at(t, x, y, p, cell)
				else:
					var c: Color = _color_for_tile(t, x, y)
					if c.a > 0.0:
						var r: Rect2 = Rect2(p, cell)
						draw_rect(r, c, true)

func _draw_wall_at(x: int, y: int, p: Vector2, cell: Vector2) -> void:
	if _wall_tex == null:
		draw_rect(Rect2(p, cell), Color(1, 1, 1, 1), true)
		return
	var wall_autotile_script: Script = load("res://scripts/rendering/WallAutotile.gd") as Script
	var mask8: int = int(wall_autotile_script.call("neighbor_mask_8", func(dx: int, dy: int) -> bool:
		return _board.is_wall(x + dx, y + dy)
	))
	var region: Rect2i = wall_autotile_script.call("atlas_region_for_mask8", mask8) as Rect2i
	var base: Color = WALL_TINT
	base.a = 1.0

	# Side-clear darkening (approximation of web's clipped gradient overlay).
	var left_p: float = 0.0
	var right_p: float = 0.0
	if _model != null:
		left_p = float(_model.get("left_side_clear_progress"))
		right_p = float(_model.get("right_side_clear_progress"))

	var prog: float = left_p if x < 14 else right_p
	var dark_alpha: float = 0.0
	if prog > 0.0001:
		var dist_to_seam: float = abs(float(x) - 13.5)
		var fall: float = clamp(dist_to_seam / SIDE_CLEAR_SEAM_FALLOFF_TILES, 0.0, 1.0)
		dark_alpha = SIDE_CLEAR_DARK_MAX * prog * fall

	# Multiply tint (white atlas) and then darken toward background.
	var tint: Color = base
	tint.r = lerp(tint.r, 2.0 / 255.0, dark_alpha)
	tint.g = lerp(tint.g, 6.0 / 255.0, dark_alpha)
	tint.b = lerp(tint.b, 23.0 / 255.0, dark_alpha)

	draw_texture_rect_region(_wall_tex, Rect2(p, cell), region, tint, false)

func _draw_exit_at(p: Vector2, cell: Vector2) -> void:
	if _exit_tex == null:
		draw_rect(Rect2(p + cell * 0.2, cell * 0.6), Color(1, 1, 1, 0.8), true)
		return
	draw_texture_rect(_exit_tex, Rect2(p, cell), false, Color(1, 1, 1, 1))

func _draw_pellet_at(tile_id: int, x: int, y: int, p: Vector2, cell: Vector2) -> void:
	var alive: bool = true
	if _model != null:
		var pellets: Variant = _model.get("pellets")
		if typeof(pellets) == TYPE_ARRAY:
			var row: Array = (pellets as Array)[y] as Array
			alive = row[x] as bool
	if not alive:
		return

	var alpha: float = 1.0
	var size_scale: float = 0.62
	if tile_id == Tile.Id.PELLET:
		alpha = 0.85
		size_scale = 0.8
	elif tile_id == Tile.Id.POWER_PELLET:
		alpha = 1.0
		size_scale = 1.5

	var size: Vector2 = cell * size_scale
	var off: Vector2 = (cell - size) * 0.5
	if _pellet_tex == null:
		draw_rect(Rect2(p + off, size), Color(1, 1, 1, alpha), true)
		return
	draw_texture_rect(_pellet_tex, Rect2(p + off, size), false, Color(1, 1, 1, alpha))

func _load_png_texture(res_path: String) -> Texture2D:
	if not FileAccess.file_exists(res_path):
		push_error("PNG not found: %s" % res_path)
		return null

	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(res_path)
	if bytes.size() == 0:
		push_error("PNG empty/unreadable: %s" % res_path)
		return null

	var img: Image = Image.new()
	var err: Error = img.load_png_from_buffer(bytes)
	if err != OK:
		push_error("PNG decode failed (%s): %s" % [str(err), res_path])
		return null

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	return tex

func _load_svg_texture(res_path: String, raster_px: int) -> Texture2D:
	if not FileAccess.file_exists(res_path):
		push_error("SVG not found: %s" % res_path)
		return null

	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(res_path)
	if bytes.size() == 0:
		push_error("SVG empty/unreadable: %s" % res_path)
		return null

	var img: Image = Image.new()
	# Godot rasterizes SVG into an Image; we pick a fixed size for now.
	var err: Error = img.load_svg_from_buffer(bytes, float(raster_px))
	if err != OK:
		push_error("SVG decode failed (%s): %s" % [str(err), res_path])
		return null

	var tex: ImageTexture = ImageTexture.create_from_image(img)
	return tex

func _color_for_tile(tile_id: int, x: int, y: int) -> Color:
	if tile_id == Tile.Id.WALL:
		return Color(1, 1, 1, 1)
	if tile_id == Tile.Id.PELLET or tile_id == Tile.Id.POWER_PELLET:
		if _model == null:
			return Color(0.9, 0.9, 0.9, 0.35)
		var pellets: Variant = _model.get("pellets")
		if typeof(pellets) != TYPE_ARRAY:
			return Color(0.9, 0.9, 0.9, 0.35)
		var row: Array = (pellets as Array)[y] as Array
		var alive: bool = row[x] as bool
		if not alive:
			return Color(0, 0, 0, 0)
		if tile_id == Tile.Id.POWER_PELLET:
			return Color(1, 1, 1, 0.8)
		return Color(0.9, 0.9, 0.9, 0.35)
	if tile_id == Tile.Id.EXIT:
		return Color(0.9, 0.9, 0.9, 0.7)
	if tile_id == Tile.Id.GHOST_HOUSE:
		return Color(0, 0, 0, 0) # invisible
	return Color(0, 0, 0, 0)
