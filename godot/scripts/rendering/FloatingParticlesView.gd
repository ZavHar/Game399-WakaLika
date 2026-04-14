extends Node2D

const MAX_PARTICLES: int = 88
const MIN_SPEED: float = 6.0
const MAX_SPEED: float = 18.0
const MIN_RADIUS: float = 0.9
const MAX_RADIUS: float = 2.2

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _particles: Array = [] # Array[Dictionary]
var _viewport_size: Vector2 = Vector2(1280, 720)

func _ready() -> void:
	_rng.randomize()
	_viewport_size = get_viewport_rect().size
	_reseed_particles()

func _process(delta: float) -> void:
	var rect: Rect2 = get_viewport_rect()
	_viewport_size = rect.size
	for i: int in range(_particles.size()):
		var p: Dictionary = _particles[i] as Dictionary
		p["x"] = float(p.get("x", 0.0)) + float(p.get("vx", 0.0)) * delta
		p["y"] = float(p.get("y", 0.0)) + float(p.get("vy", 0.0)) * delta
		var x: float = float(p.get("x", 0.0))
		var y: float = float(p.get("y", 0.0))
		if x < -8.0:
			p["x"] = _viewport_size.x + 8.0
		elif x > _viewport_size.x + 8.0:
			p["x"] = -8.0
		if y < -8.0:
			p["y"] = _viewport_size.y + 8.0
		elif y > _viewport_size.y + 8.0:
			p["y"] = -8.0
		_particles[i] = p
	queue_redraw()

func _draw() -> void:
	for p_v: Variant in _particles:
		var p: Dictionary = p_v as Dictionary
		var x: float = float(p.get("x", 0.0))
		var y: float = float(p.get("y", 0.0))
		var r: float = float(p.get("r", 1.0))
		var a: float = float(p.get("a", 0.14))
		draw_circle(Vector2(x, y), r, Color(0.72, 0.84, 1.0, a))

func _reseed_particles() -> void:
	_particles = []
	for i: int in range(MAX_PARTICLES):
		var ang: float = _rng.randf_range(0.0, TAU)
		var speed: float = _rng.randf_range(MIN_SPEED, MAX_SPEED)
		_particles.append({
			"x": _rng.randf_range(0.0, _viewport_size.x),
			"y": _rng.randf_range(0.0, _viewport_size.y),
			"vx": cos(ang) * speed * 0.5,
			"vy": sin(ang) * speed,
			"r": _rng.randf_range(MIN_RADIUS, MAX_RADIUS),
			"a": _rng.randf_range(0.05, 0.18),
		})
