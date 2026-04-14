extends RefCounted
class_name GhostInterpolation

## One-step toroidal slide from tile centers (fixes tunnel "glide across map").

static func slide_delta_torus(from: Vector2i, to: Vector2i, full_w: int, h: int) -> Vector2i:
	var dx: int = to.x - from.x
	var dy: int = to.y - from.y
	if abs(dx) + abs(dy) == 1:
		return Vector2i(dx, dy)
	if dy == 0 and from.y == to.y:
		if from.x == full_w - 1 and to.x == 0:
			return Vector2i(1, 0)
		if from.x == 0 and to.x == full_w - 1:
			return Vector2i(-1, 0)
	if dx == 0 and from.x == to.x:
		if from.y == h - 1 and to.y == 0:
			return Vector2i(0, 1)
		if from.y == 0 and to.y == h - 1:
			return Vector2i(0, -1)
	return Vector2i.ZERO

## Extended tile coords (may be slightly outside [0,full_w)) so warp matches Pac / double-draw.
static func visual_center_fractional(from: Vector2i, to: Vector2i, t: float, full_w: int, h: int) -> Vector2:
	var d: Vector2i = slide_delta_torus(from, to, full_w, h)
	var ax: float = float(from.x) + 0.5 + float(d.x) * t
	var ay: float = float(from.y) + 0.5 + float(d.y) * t
	return Vector2(ax, ay)
