extends Control
class_name LivesView

@export var game_root_path: NodePath = NodePath("../../MarginPlayfield/AspectBoard/SubViewportContainer/SubViewport/GameRoot")

const ICON_SIZE_PX: float = 34.0
const ICON_SPACING_PX: float = 8.0

var _game_root: Node = null
var _pac_tex: Texture2D = null

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pac_tex = _load_svg_texture("res://assets/characters/pacman.svg", 128)
	_game_root = get_node_or_null(game_root_path)

func _process(_delta: float) -> void:
	if _game_root == null:
		_game_root = get_node_or_null(game_root_path)
	queue_redraw()

func _draw() -> void:
	if _pac_tex == null or _game_root == null or not _game_root.has_method("get_model"):
		return
	var model: RefCounted = _game_root.call("get_model") as RefCounted
	if model == null:
		return
	var lives: int = int(model.get("lives"))
	var n: int = max(0, lives - 1)
	if n <= 0:
		return

	var sz: float = ICON_SIZE_PX
	var y: float = maxf(0.0, size.y - sz)
	for i: int in range(n):
		var x: float = float(i) * (sz + ICON_SPACING_PX)
		draw_texture_rect(_pac_tex, Rect2(Vector2(x, y), Vector2(sz, sz)), false, Color(1, 1, 1, 1))

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

