extends SceneTree

const LEVELS_JSON_PATH: String = "res://assets/data/levelGrids.json"
const FIXED_DT: float = 1.0 / 60.0
const STEPS_PER_LAYOUT: int = 300

var _failures: PackedStringArray = PackedStringArray()
var _warnings: PackedStringArray = PackedStringArray()
var _layouts_checked: int = 0

func _initialize() -> void:
	var ok: bool = _run_all_checks()
	_print_report()
	quit(0 if ok else 1)

func _run_all_checks() -> bool:
	var lg: LevelGrids = LevelGrids.load_from_path(LEVELS_JSON_PATH)
	var names: PackedStringArray = lg.get_layout_names_sorted()
	if names.is_empty():
		_failures.append("No layouts found at %s." % LEVELS_JSON_PATH)
		return false

	for layout_name: String in names:
		_check_layout(layout_name, lg.get_layout(layout_name))
		_layouts_checked += 1
	return _failures.is_empty()

func _check_layout(layout_name: String, left_half: Array) -> void:
	var board: BoardModel = BoardModel.from_left_half(left_half)
	var gm_script: Script = load("res://scripts/game/GameModel.gd") as Script
	var gm: RefCounted = gm_script.new() as RefCounted
	gm.call("init_from_board", board)

	var left_pellets: int = int(gm.get("pellets_left_left"))
	var right_pellets: int = int(gm.get("pellets_left_right"))
	if left_pellets + right_pellets <= 0:
		_failures.append("[%s] No pellets detected after init." % layout_name)

	var pac: Vector2i = gm.call("pac_tile") as Vector2i
	var ghosts: Array = gm.get("ghosts") as Array
	for g_v: Variant in ghosts:
		var g: RefCounted = g_v as RefCounted
		var gid: String = g.get("id") as String
		var gpos: Vector2i = g.get("pos") as Vector2i
		var gdir: int = int(g.get("dir"))
		var path: Array = gm.call("find_path_bfs", gpos, pac, gdir, true, false) as Array
		if path.is_empty():
			_warnings.append("[%s] No ghost path from %s to pac spawn." % [layout_name, gid])

	for i: int in range(STEPS_PER_LAYOUT):
		gm.call("step", FIXED_DT)

	var pac_pos: Vector2 = gm.get("pac_pos") as Vector2
	if is_nan(pac_pos.x) or is_nan(pac_pos.y):
		_failures.append("[%s] Pac position became NaN after simulation." % layout_name)

	if board.left.size() != BoardModel.H or board.right.size() != BoardModel.H:
		_failures.append("[%s] Board dimensions changed unexpectedly." % layout_name)

func _print_report() -> void:
	print("--- Phase 8 checks ---")
	for w: String in _warnings:
		print("WARN: %s" % w)
	for f: String in _failures:
		push_error("FAIL: %s" % f)
	if _failures.is_empty():
		print("PASS: %d layouts checked, %d warnings." % [_layouts_checked, _warnings.size()])
	else:
		print("FAIL: %d failures, %d warnings." % [_failures.size(), _warnings.size()])
