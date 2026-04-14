extends RefCounted
class_name LevelGrids

const EXPECTED_ROWS: int = 36
const EXPECTED_COLS_HALF: int = 14

var layouts: Dictionary = {} # String -> Array[Array[int]]

static func load_from_path(json_path: String) -> LevelGrids:
	var lg: LevelGrids = LevelGrids.new()
	lg._load(json_path)
	return lg

func _load(json_path: String) -> void:
	layouts = {}

	if not FileAccess.file_exists(json_path):
		push_error("LevelGrids JSON not found: %s" % json_path)
		return

	var f: FileAccess = FileAccess.open(json_path, FileAccess.READ)
	if f == null:
		push_error("Failed to open LevelGrids JSON: %s" % json_path)
		return

	var text: String = f.get_as_text()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("LevelGrids JSON root must be an object/dictionary.")
		return

	var dict: Dictionary = parsed as Dictionary
	for k: Variant in dict.keys():
		if typeof(k) != TYPE_STRING:
			push_error("Level layout key must be a string.")
			continue

		var name: String = k as String
		var grid: Variant = dict[name]
		if not _validate_grid(name, grid):
			continue

		layouts[name] = grid

func get_layout_names_sorted() -> PackedStringArray:
	var names: PackedStringArray = PackedStringArray()
	for k: Variant in layouts.keys():
		names.append(k as String)
	names.sort()
	return names

func get_layout(name: String) -> Array:
	if not layouts.has(name):
		return []
	return layouts[name] as Array

func _validate_grid(name: String, grid: Variant) -> bool:
	if typeof(grid) != TYPE_ARRAY:
		push_error('Layout "%s" must be an array of rows.' % name)
		return false

	var rows: Array = grid as Array
	if rows.size() != EXPECTED_ROWS:
		push_error('Layout "%s" must have %d rows, got %d.' % [name, EXPECTED_ROWS, rows.size()])
		return false

	for y: int in range(EXPECTED_ROWS):
		var row_v: Variant = rows[y]
		if typeof(row_v) != TYPE_ARRAY:
			push_error('Layout "%s" row %d must be an array.' % [name, y])
			return false

		var row: Array = row_v as Array
		if row.size() != EXPECTED_COLS_HALF:
			push_error('Layout "%s" row %d must have %d cols, got %d.' % [name, y, EXPECTED_COLS_HALF, row.size()])
			return false

		for x: int in range(EXPECTED_COLS_HALF):
			var cell: Variant = row[x]
			var t: int = _coerce_int(cell)
			if t == -999999:
				push_error('Layout "%s" cell (%d,%d) must be a whole number.' % [name, x, y])
				return false
			row[x] = t

	return true

func _coerce_int(v: Variant) -> int:
	if typeof(v) == TYPE_INT:
		return v as int
	if typeof(v) == TYPE_FLOAT:
		var f: float = v as float
		var i: int = int(f)
		if abs(f - float(i)) < 0.00001:
			return i
	return -999999
