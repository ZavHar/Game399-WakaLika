extends Node2D

const CELL_PX: float = 18.0

const FRUIT_COLOR: Color = Color(0.976, 0.451, 0.086, 1.0) # approx #f97316
const FRUIT_SIDE_FLASH_DURATION_MS: float = 250.0
const FRUIT_SIDE_FLASH_MAX_ALPHA: float = 0.35
const FRUIT_SIDE_FLASH_FADE_POW: float = 2.0

var _board: BoardModel = null
var _model: RefCounted = null

var _pellet_tex: Texture2D = null
var _exit_tex: Texture2D = null

func set_board(board: BoardModel) -> void:
	_board = board
	queue_redraw()

func set_model(m: RefCounted) -> void:
	_model = m
	queue_redraw()

func _ready() -> void:
	_pellet_tex = _load_svg_texture("res://assets/tiles/pellet-white.svg", 64)
	_exit_tex = _load_svg_texture("res://assets/tiles/exit-white.svg", 64)

func _process(_delta: float) -> void:
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
			if t == Tile.Id.EXIT:
				_draw_exit(p, cell)
			elif t == Tile.Id.PELLET or t == Tile.Id.POWER_PELLET:
				_draw_pellet(t, x, y, p, cell)

	_draw_fruit(cell)
	_draw_side_flash(cell)

func _draw_exit(p: Vector2, cell: Vector2) -> void:
	if _exit_tex == null:
		draw_rect(Rect2(p + cell * 0.2, cell * 0.6), Color(1, 1, 1, 0.8), true)
		return
	draw_texture_rect(_exit_tex, Rect2(p, cell), false, Color(1, 1, 1, 1))

func _draw_pellet(tile_id: int, x: int, y: int, p: Vector2, cell: Vector2) -> void:
	if _model != null:
		var pellets: Variant = _model.get("pellets")
		if typeof(pellets) == TYPE_ARRAY:
			var row: Array = (pellets as Array)[y] as Array
			var alive: bool = row[x] as bool
			if not alive:
				return

	if tile_id == Tile.Id.POWER_PELLET:
		# Web parity: warm glow (not sprite-based).
		var cx: float = p.x + cell.x * 0.5
		var cy: float = p.y + cell.y * 0.5
		draw_circle(Vector2(cx, cy), min(cell.x, cell.y) * 0.23, Color(0.984, 0.749, 0.141, 0.95))
		return

	# Normal pellet sprite
	var alpha: float = 0.85
	var size_scale: float = 0.8
	var size: Vector2 = cell * size_scale
	var off: Vector2 = (cell - size) * 0.5
	if _pellet_tex == null:
		draw_rect(Rect2(p + off, size), Color(1, 1, 1, alpha), true)
		return
	draw_texture_rect(_pellet_tex, Rect2(p + off, size), false, Color(1, 1, 1, alpha))

func _draw_fruit(cell: Vector2) -> void:
	if _model == null:
		return
	var left_on: bool = bool(_model.get("fruit_active_left"))
	var right_on: bool = bool(_model.get("fruit_active_right"))
	if not left_on and not right_on:
		return

	# Web uses LEFT_FRUIT_SPAWN_LOCAL = {x:9,y:17} mirrored for right.
	var left: Vector2 = Vector2(9.0, 17.0)
	var right_x: float = float(2 * 14 - 1 - int(left.x))
	var right: Vector2 = Vector2(right_x, 17.0)

	if left_on:
		_draw_fruit_at(left, cell)
	if right_on:
		_draw_fruit_at(right, cell)

func _draw_fruit_at(tile: Vector2, cell: Vector2) -> void:
	var cx: float = (tile.x + 0.5) * cell.x
	var cy: float = (tile.y + 0.5) * cell.y
	draw_circle(Vector2(cx, cy), cell.x * 0.22, FRUIT_COLOR)

func _draw_side_flash(cell: Vector2) -> void:
	if _model == null:
		return
	var left_ms: float = float(_model.get("left_side_fruit_flash_ms"))
	var right_ms: float = float(_model.get("right_side_fruit_flash_ms"))
	if left_ms <= 0.0 and right_ms <= 0.0:
		return

	var w_tiles: float = float(BoardModel.FULL_W)
	var h_tiles: float = float(BoardModel.H)

	var left_p: float = min(1.0, left_ms / FRUIT_SIDE_FLASH_DURATION_MS)
	if left_p > 0.0:
		var a: float = FRUIT_SIDE_FLASH_MAX_ALPHA * pow(left_p, FRUIT_SIDE_FLASH_FADE_POW)
		draw_rect(Rect2(Vector2.ZERO, Vector2(14.0 * cell.x, h_tiles * cell.y)), Color(1, 1, 1, a), true)

	var right_p: float = min(1.0, right_ms / FRUIT_SIDE_FLASH_DURATION_MS)
	if right_p > 0.0:
		var a2: float = FRUIT_SIDE_FLASH_MAX_ALPHA * pow(right_p, FRUIT_SIDE_FLASH_FADE_POW)
		draw_rect(Rect2(Vector2(14.0 * cell.x, 0.0), Vector2((w_tiles - 14.0) * cell.x, h_tiles * cell.y)), Color(1, 1, 1, a2), true)

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
