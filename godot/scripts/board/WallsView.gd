extends Node2D

const CELL_PX: float = 18.0

const WALL_TINT: Color = Color(0.0, 48.0 / 255.0, 206.0 / 255.0, 0.65)
const WALL_TILE_PX: int = 32
const ACTIVE_LAYOUT_PATH: String = "res://assets/data/active_layout.txt"

var _board: BoardModel = null
var _model: RefCounted = null
var _wall_tex: Texture2D = null
var _wall_img: Image = null
var _wall_mask_tex: Texture2D = null
var _wall_autotile_script: Script = null

func load_default_layout() -> void:
	var lg: LevelGrids = LevelGrids.load_from_path("res://assets/data/levelGrids.json")
	var names: PackedStringArray = lg.get_layout_names_sorted()
	if names.size() == 0:
		push_error("No layouts found in levelGrids.json")
		return
	var layout_name: String = names[0]
	var requested: String = _read_active_layout_name()
	if requested != "" and lg.layouts.has(requested):
		layout_name = requested
	var left_half: Array = lg.get_layout(layout_name)
	_board = BoardModel.from_left_half(left_half)
	print("Loaded layouts: %d (active: %s)" % [names.size(), layout_name])
	# Build wall mask eagerly so overlay shaders can use it immediately.
	if _wall_img == null:
		_wall_img = _load_png_image("res://assets/tiles/maze-wall-atlas.png")
	if _wall_mask_tex == null and _wall_img != null:
		_wall_mask_tex = _build_wall_mask_texture()
	queue_redraw()

func get_board_model() -> BoardModel:
	return _board

func get_wall_mask_texture() -> Texture2D:
	return _wall_mask_tex

func set_board(board: BoardModel) -> void:
	_board = board
	queue_redraw()

func rebuild_after_board_change() -> void:
	if _board == null or _wall_img == null:
		return
	_wall_mask_tex = _build_wall_mask_texture()
	queue_redraw()

func set_model(m: RefCounted) -> void:
	_model = m
	queue_redraw()

func _ready() -> void:
	_wall_tex = _load_png_texture("res://assets/tiles/maze-wall-atlas.png")
	_wall_img = _load_png_image("res://assets/tiles/maze-wall-atlas.png")
	_wall_autotile_script = load("res://scripts/rendering/WallAutotile.gd") as Script

func _draw() -> void:
	if _board == null:
		return

	var w: int = BoardModel.FULL_W
	var h: int = BoardModel.H
	var cell: Vector2 = Vector2(CELL_PX, CELL_PX)
	for y: int in range(h):
		for x: int in range(w):
			if not _board.is_wall(x, y):
				continue
			var p: Vector2 = Vector2(float(x) * CELL_PX, float(y) * CELL_PX)
			_draw_wall_at(x, y, p, cell)

func _draw_wall_at(x: int, y: int, p: Vector2, cell: Vector2) -> void:
	if _wall_tex == null:
		draw_rect(Rect2(p, cell), Color(1, 1, 1, 1), true)
		return

	if _wall_autotile_script == null:
		return
	var mask8: int = int(_wall_autotile_script.call("neighbor_mask_8", func(dx: int, dy: int) -> bool:
		return _board.is_wall(x + dx, y + dy)
	))
	var region: Rect2i = _wall_autotile_script.call("atlas_region_for_mask8", mask8) as Rect2i

	var tint: Color = WALL_TINT
	tint.a = 1.0

	draw_texture_rect_region(_wall_tex, Rect2(p, cell), region, tint, false)

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
	return ImageTexture.create_from_image(img)

func _load_png_image(res_path: String) -> Image:
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
	return img

func _build_wall_mask_texture() -> Texture2D:
	# Build a pixel-accurate wall alpha mask by blitting atlas regions for each wall tile.
	var w_px: int = BoardModel.FULL_W * WALL_TILE_PX
	var h_px: int = BoardModel.H * WALL_TILE_PX
	var mask: Image = Image.create(w_px, h_px, false, Image.FORMAT_RGBA8)
	mask.fill(Color(0, 0, 0, 0))

	if _wall_autotile_script == null:
		_wall_autotile_script = load("res://scripts/rendering/WallAutotile.gd") as Script
	for y: int in range(BoardModel.H):
		for x: int in range(BoardModel.FULL_W):
			if not _board.is_wall(x, y):
				continue
			var mask8: int = int(_wall_autotile_script.call("neighbor_mask_8", func(dx: int, dy: int) -> bool:
				return _board.is_wall(x + dx, y + dy)
			))
			var region: Rect2i = _wall_autotile_script.call("atlas_region_for_mask8", mask8) as Rect2i
			mask.blit_rect(_wall_img, region, Vector2i(x * WALL_TILE_PX, y * WALL_TILE_PX))

	return ImageTexture.create_from_image(mask)

func _read_active_layout_name() -> String:
	if not FileAccess.file_exists(ACTIVE_LAYOUT_PATH):
		return ""
	var f: FileAccess = FileAccess.open(ACTIVE_LAYOUT_PATH, FileAccess.READ)
	if f == null:
		return ""
	var raw: String = f.get_as_text().strip_edges()
	return raw
