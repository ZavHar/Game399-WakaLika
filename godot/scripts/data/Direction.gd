class_name Direction

enum Id {
	UP = 0,
	DOWN = 1,
	LEFT = 2,
	RIGHT = 3,
}

static func to_vec(dir: int) -> Vector2:
	if dir == Id.UP:
		return Vector2(0.0, -1.0)
	if dir == Id.DOWN:
		return Vector2(0.0, 1.0)
	if dir == Id.LEFT:
		return Vector2(-1.0, 0.0)
	if dir == Id.RIGHT:
		return Vector2(1.0, 0.0)
	return Vector2.ZERO

