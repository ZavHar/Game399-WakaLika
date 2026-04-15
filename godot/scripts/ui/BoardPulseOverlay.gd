extends Control

const PULSE_INTERVAL_S: float = 60.0/136.0
const PULSE_LIFE_S: float = 0.5
const PULSE_MAX_EXPAND_PX: float = 100.0
const PULSE_MAX_ALPHA: float = 0.75
const PULSE_STROKE_PX: float = 2.5
const PULSE_COLOR: Color = Color(0.30, 0.65, 1.0, 1.0)

@export var board_target_path: NodePath = NodePath("../MarginPlayfield/AspectBoard/SubViewportContainer")
@export var game_root_path: NodePath = NodePath("../MarginPlayfield/AspectBoard/SubViewportContainer/SubViewport/GameRoot")

var _target: Control = null
var _game_root: Node = null
var _pulse_timer_s: float = 0.0
var _pulses: Array = [] # Array[Dictionary] { "life_s": float }

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resolve_target()
	_game_root = get_node_or_null(game_root_path)

func _process(delta: float) -> void:
	if _target == null:
		_resolve_target()
	if _game_root == null:
		_game_root = get_node_or_null(game_root_path)

	# During early load/layout, keep this overlay dormant to avoid transient degenerate transforms.
	if _target == null or _target.size.x <= 0.0 or _target.size.y <= 0.0 or size.x <= 0.0 or size.y <= 0.0:
		_pulse_timer_s = 0.0
		_pulses = []
		return
	if _game_root == null or not _game_root.has_method("get_model"):
		_pulse_timer_s = 0.0
		_pulses = []
		return
	var model: RefCounted = _game_root.call("get_model") as RefCounted
	if model == null:
		_pulse_timer_s = 0.0
		_pulses = []
		return
	if bool(model.get("is_game_over")):
		_pulse_timer_s = 0.0
		_pulses = []
		queue_redraw()
		return

	_pulse_timer_s += delta
	if _pulse_timer_s >= PULSE_INTERVAL_S:
		_pulse_timer_s -= PULSE_INTERVAL_S
		_pulses.append({"life_s": PULSE_LIFE_S})

	var next: Array = []
	for p_v: Variant in _pulses:
		var p: Dictionary = p_v as Dictionary
		var life_s: float = float(p.get("life_s", 0.0)) - delta
		if life_s <= 0.0:
			continue
		p["life_s"] = life_s
		next.append(p)
	_pulses = next

	queue_redraw()

func _draw() -> void:
	if _target == null:
		return
	if _target.size.x <= 0.0 or _target.size.y <= 0.0:
		return
	if size.x <= 0.0 or size.y <= 0.0:
		return
	var global_rect: Rect2 = Rect2(_target.global_position, _target.size)
	var p0: Vector2 = global_rect.position - global_position
	var base_r: Rect2 = Rect2(p0, global_rect.size)
	var base_col: Color = _shifted_pulse_color()
	for p_v: Variant in _pulses:
		var p: Dictionary = p_v as Dictionary
		var life_k: float = clampf(float(p.get("life_s", 0.0)) / PULSE_LIFE_S, 0.0, 1.0)
		var t: float = 1.0 - life_k
		var expand: float = t * PULSE_MAX_EXPAND_PX
		var alpha: float = PULSE_MAX_ALPHA * pow(life_k, 1.35)
		var pr: Rect2 = Rect2(
			base_r.position.x - expand,
			base_r.position.y - expand,
			base_r.size.x + 2.0 * expand,
			base_r.size.y + 2.0 * expand
		)
		draw_rect(pr, Color(base_col.r, base_col.g, base_col.b, alpha), false, PULSE_STROKE_PX)

func _resolve_target() -> void:
	_target = get_node_or_null(board_target_path) as Control
	if _target != null:
		return
	var p: Node = get_parent()
	if p != null:
		_target = p.get_node_or_null("MarginPlayfield/AspectBoard/SubViewportContainer") as Control

func _shifted_pulse_color() -> Color:
	var c: Color = PULSE_COLOR
	if _game_root == null or not _game_root.has_method("get_model"):
		return c
	var model: RefCounted = _game_root.call("get_model") as RefCounted
	if model == null:
		return c
	var hk: float = float(model.get("hue_shift_amount"))
	if hk <= 0.0:
		return c
	var h: float = fposmod(c.h + hk, 1.0)
	return Color.from_hsv(h, c.s, c.v, c.a)
