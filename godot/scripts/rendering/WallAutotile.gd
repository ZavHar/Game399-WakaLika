extends RefCounted
class_name WallAutotile

# Atlas settings for `assets/tiles/wall-atlas.png` (rhdunn/maze-tileset sand/tiles.png).
const TILE_PX: int = 32
const ATLAS_COLS: int = 7

# Lookup table from `tiles.256` in rhdunn/maze-tileset (CC-BY-SA 3.0).
# Index is a neighbor bitmask encoded as:
# N=1, S=2, W=4, E=8, NW=16, SW=32, NE=64, SE=128.
const LOOKUP_256: Array[int] = [
	16, 7, 6, 3, 5, 11, 9, 12, 4, 10, 8, 13, 2, 14, 15, 1,
	16, 7, 6, 3, 5, 25, 9, 45, 4, 10, 8, 13, 2, 41, 15, 37,
	16, 7, 6, 3, 5, 11, 23, 43, 4, 10, 8, 13, 2, 14, 39, 35,
	16, 7, 6, 3, 5, 25, 23, 19, 4, 10, 8, 13, 2, 41, 39, 31,
	16, 7, 6, 3, 5, 11, 9, 12, 4, 24, 8, 44, 2, 40, 15, 36,
	16, 7, 6, 3, 5, 25, 9, 45, 4, 24, 8, 44, 2, 21, 15, 33,
	16, 7, 6, 3, 5, 11, 23, 43, 4, 24, 8, 44, 2, 40, 39, 46,
	16, 7, 6, 3, 5, 25, 23, 19, 4, 24, 8, 44, 2, 21, 39, 29,
	16, 7, 6, 3, 5, 11, 9, 12, 4, 10, 22, 42, 2, 14, 38, 34,
	16, 7, 6, 3, 5, 25, 9, 45, 4, 10, 22, 42, 2, 41, 38, 47,
	16, 7, 6, 3, 5, 11, 23, 43, 4, 10, 22, 42, 2, 14, 20, 32,
	16, 7, 6, 3, 5, 25, 23, 19, 4, 10, 22, 42, 2, 41, 20, 27,
	16, 7, 6, 3, 5, 11, 9, 12, 4, 24, 22, 18, 2, 40, 38, 30,
	16, 7, 6, 3, 5, 25, 9, 45, 4, 24, 22, 18, 2, 21, 38, 28,
	16, 7, 6, 3, 5, 11, 23, 43, 4, 24, 22, 18, 2, 40, 20, 26,
	16, 7, 6, 3, 5, 25, 23, 19, 4, 24, 22, 18, 2, 21, 20, 17,
]

static func neighbor_mask_8(get_is_wall: Callable) -> int:
	# Returns an 8-neighbor mask using this order:
	# N, NE, E, SE, S, SW, W, NW (bit positions 0..7)
	var out: int = 0
	var offsets: Array[Vector2i] = [
		Vector2i(0, -1),
		Vector2i(1, -1),
		Vector2i(1, 0),
		Vector2i(1, 1),
		Vector2i(0, 1),
		Vector2i(-1, 1),
		Vector2i(-1, 0),
		Vector2i(-1, -1),
	]
	for i: int in range(offsets.size()):
		var d: Vector2i = offsets[i]
		if bool(get_is_wall.call(d.x, d.y)):
			out |= (1 << i)
	return out

static func to_tileset_mask(mask8: int) -> int:
	var n: bool = (mask8 & (1 << 0)) != 0
	var ne: bool = (mask8 & (1 << 1)) != 0
	var e: bool = (mask8 & (1 << 2)) != 0
	var se: bool = (mask8 & (1 << 3)) != 0
	var s: bool = (mask8 & (1 << 4)) != 0
	var sw: bool = (mask8 & (1 << 5)) != 0
	var w: bool = (mask8 & (1 << 6)) != 0
	var nw: bool = (mask8 & (1 << 7)) != 0

	var out: int = 0
	if n:
		out += 1
	if s:
		out += 2
	if w:
		out += 4
	if e:
		out += 8
	if nw:
		out += 16
	if sw:
		out += 32
	if ne:
		out += 64
	if se:
		out += 128
	return out

static func atlas_region_for_mask8(mask8: int) -> Rect2i:
	var tm: int = to_tileset_mask(mask8)
	var tile_index: int = int(LOOKUP_256[tm])
	var sx: int = (tile_index % ATLAS_COLS) * TILE_PX
	var sy: int = int(floor(float(tile_index) / float(ATLAS_COLS))) * TILE_PX
	return Rect2i(sx, sy, TILE_PX, TILE_PX)

