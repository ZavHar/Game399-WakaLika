extends SceneTree

const LEVELS_JSON_PATH: String = "res://assets/data/levelGrids.json"
const ACTIVE_LAYOUT_PATH: String = "res://assets/data/active_layout.txt"
const VALID_TILES: Array[int] = [0, 1, 2, 3, 4, 5]

func _initialize() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.is_empty():
		_print_usage()
		quit(1)
		return

	var cmd: String = args[0]
	if cmd == "list":
		_cmd_list()
		quit(0)
		return
	if cmd == "validate":
		quit(0 if _cmd_validate() else 1)
		return
	if cmd == "set-active":
		if args.size() < 2:
			push_error("set-active requires a layout name")
			quit(1)
			return
		quit(0 if _cmd_set_active(args[1]) else 1)
		return
	if cmd == "show-active":
		quit(0 if _cmd_show_active() else 1)
		return

	push_error("Unknown command: %s" % cmd)
	_print_usage()
	quit(1)

func _load_levels() -> LevelGrids:
	return LevelGrids.load_from_path(LEVELS_JSON_PATH)

func _cmd_list() -> void:
	var lg: LevelGrids = _load_levels()
	var names: PackedStringArray = lg.get_layout_names_sorted()
	print("Layouts (%d):" % names.size())
	for n: String in names:
		print("- %s" % n)

func _cmd_validate() -> bool:
	var lg: LevelGrids = _load_levels()
	var names: PackedStringArray = lg.get_layout_names_sorted()
	if names.is_empty():
		push_error("No layouts found in %s" % LEVELS_JSON_PATH)
		return false

	for n: String in names:
		var grid: Array = lg.get_layout(n)
		if grid.size() != 36:
			push_error("[%s] expected 36 rows, got %d" % [n, grid.size()])
			return false
		for y: int in range(grid.size()):
			var row: Array = grid[y] as Array
			if row.size() != 14:
				push_error("[%s] row %d expected 14 cols, got %d" % [n, y, row.size()])
				return false
			for x: int in range(row.size()):
				var t: int = int(row[x])
				if not VALID_TILES.has(t):
					push_error("[%s] invalid tile %d at (%d,%d)" % [n, t, x, y])
					return false
	print("Validation passed for %d layout(s)." % names.size())
	return true

func _cmd_set_active(layout_name: String) -> bool:
	var lg: LevelGrids = _load_levels()
	if not lg.layouts.has(layout_name):
		push_error("Layout not found: %s" % layout_name)
		return false
	var f: FileAccess = FileAccess.open(ACTIVE_LAYOUT_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Cannot write %s" % ACTIVE_LAYOUT_PATH)
		return false
	f.store_string(layout_name + "\n")
	print("Active layout set to: %s" % layout_name)
	return true

func _cmd_show_active() -> bool:
	var current: String = ""
	if FileAccess.file_exists(ACTIVE_LAYOUT_PATH):
		var f: FileAccess = FileAccess.open(ACTIVE_LAYOUT_PATH, FileAccess.READ)
		if f != null:
			current = f.get_as_text().strip_edges()
	if current == "":
		print("Active layout file is empty/missing; runtime defaults to first sorted layout.")
		return true
	print("Active layout: %s" % current)
	return true

func _print_usage() -> void:
	print("LevelPipeline usage:")
	print("  godot --headless --path <project> --script res://scripts/tools/LevelPipeline.gd list")
	print("  godot --headless --path <project> --script res://scripts/tools/LevelPipeline.gd validate")
	print("  godot --headless --path <project> --script res://scripts/tools/LevelPipeline.gd show-active")
	print("  godot --headless --path <project> --script res://scripts/tools/LevelPipeline.gd set-active <layoutName>")
