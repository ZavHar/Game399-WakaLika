extends RefCounted
class_name BoardModel

const HALF_W: int = 14
const FULL_W: int = HALF_W * 2
const H: int = 36

var left: Array = [] # Array[Array[int]]
var right: Array = [] # Array[Array[int]]

static func from_left_half(left_half: Array) -> BoardModel:
	var b: BoardModel = BoardModel.new()
	b.left = left_half
	b.right = _mirror_half(left_half)
	return b

static func _mirror_half(left_half: Array) -> Array:
	var out: Array = []
	for y: int in range(H):
		var row: Array = left_half[y] as Array
		var r: Array = []
		r.resize(HALF_W)
		for x: int in range(HALF_W):
			r[x] = row[HALF_W - 1 - x]
		out.append(r)
	return out

func tile_at(global_x: int, y: int) -> int:
	var wx: int = _wrap_x(global_x)
	var wy: int = _wrap_y(y)
	if wx < HALF_W:
		return (left[wy] as Array)[wx] as int
	return (right[wy] as Array)[wx - HALF_W] as int

func _wrap_x(x: int) -> int:
	var m: int = x % FULL_W
	if m < 0:
		m += FULL_W
	return m

func _wrap_y(y: int) -> int:
	var m: int = y % H
	if m < 0:
		m += H
	return m

func is_wall(global_x: int, y: int) -> bool:
	return tile_at(global_x, y) == Tile.Id.WALL

func is_exit(global_x: int, y: int) -> bool:
	return tile_at(global_x, y) == Tile.Id.EXIT

func is_ghost_house(global_x: int, y: int) -> bool:
	return tile_at(global_x, y) == Tile.Id.GHOST_HOUSE

func is_pac_blocked(global_x: int, y: int) -> bool:
	var t: int = tile_at(global_x, y)
	return t == Tile.Id.WALL or t == Tile.Id.EXIT or t == Tile.Id.GHOST_HOUSE

func is_ghost_step_blocked(from_x: int, from_y: int, to_x: int, to_y: int) -> bool:
	return is_ghost_step_blocked_opts(from_x, from_y, to_x, to_y, false, false, false)

## Matches web `isGhostStepBlocked` opts: exit door when returning home; house-only shuffling when waiting.
## When `ignore_walls` is true, ghosts may phase through WALL tiles (unstick recovery only).
func is_ghost_step_blocked_opts(from_x: int, from_y: int, to_x: int, to_y: int, allow_exit_door: bool, restrict_to_ghost_house: bool, ignore_walls: bool = false) -> bool:
	var to_t: int = tile_at(to_x, to_y)
	if restrict_to_ghost_house:
		return to_t != Tile.Id.GHOST_HOUSE
	if ignore_walls:
		if to_t == Tile.Id.EXIT:
			if allow_exit_door:
				return false
			var from_t2: int = tile_at(from_x, from_y)
			return from_t2 != Tile.Id.EXIT and from_t2 != Tile.Id.GHOST_HOUSE
		return false
	if to_t == Tile.Id.WALL:
		return true
	if to_t != Tile.Id.EXIT:
		return false
	if allow_exit_door:
		return false
	var from_t: int = tile_at(from_x, from_y)
	return from_t != Tile.Id.EXIT and from_t != Tile.Id.GHOST_HOUSE

func nearest_pac_spawn_tile(preferred: Vector2i) -> Vector2i:
	if not is_pac_blocked(preferred.x, preferred.y):
		return preferred

	var best: Vector2i = Vector2i(0, 0)
	var best_d: int = 1 << 30
	for y: int in range(H):
		for x: int in range(FULL_W):
			if is_pac_blocked(x, y):
				continue
			var dx: int = x - preferred.x
			var dy: int = y - preferred.y
			var d: int = dx * dx + dy * dy
			if d < best_d:
				best_d = d
				best = Vector2i(x, y)
	return best
