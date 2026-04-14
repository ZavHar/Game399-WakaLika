extends Control
class_name PulseNumberLabel

@export var prefix: String = "Score: "
@export var font_size: int = 18
@export var pulse_duration_s: float = 0.22

var _raw_text: String = "Score: 0"
var _digits_text: String = "0"
var _pulse_by_digit_idx: Dictionary = {} # int -> remaining seconds

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	if _pulse_by_digit_idx.is_empty():
		return
	var next: Dictionary = {}
	for k_v: Variant in _pulse_by_digit_idx.keys():
		var idx: int = int(k_v)
		var t: float = float(_pulse_by_digit_idx[k_v]) - delta
		if t > 0.0:
			next[idx] = t
	_pulse_by_digit_idx = next
	queue_redraw()

func set_raw_text(text: String) -> void:
	_raw_text = text
	_digits_text = ""
	_pulse_by_digit_idx.clear()
	queue_redraw()

func set_score(value: int) -> void:
	var next_digits: String = str(max(0, value))
	_mark_changed_digit_pulses(_digits_text, next_digits)
	_digits_text = next_digits
	_raw_text = "%s%s" % [prefix, _digits_text]
	queue_redraw()

func _mark_changed_digit_pulses(prev_digits: String, next_digits: String) -> void:
	var n_prev: int = prev_digits.length()
	var n_next: int = next_digits.length()
	var right_pairs: int = min(n_prev, n_next)

	# Compare right-aligned digits; pulse newly changed positions.
	for i: int in range(right_pairs):
		var prev_idx: int = n_prev - 1 - i
		var next_idx: int = n_next - 1 - i
		if prev_digits[prev_idx] != next_digits[next_idx]:
			_pulse_by_digit_idx[next_idx] = pulse_duration_s

	# New leading digits (e.g., 999 -> 1000) should pulse too.
	if n_next > n_prev:
		for j: int in range(n_next - n_prev):
			_pulse_by_digit_idx[j] = pulse_duration_s

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	if font == null:
		return

	var text_full: String = _raw_text if _digits_text == "" else "%s%s" % [prefix, _digits_text]
	var total_w: float = font.get_string_size(text_full, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	var start_x: float = maxf(0.0, (size.x - total_w) * 0.5)

	if _digits_text == "":
		draw_string(font, Vector2(start_x, float(font_size)), _raw_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color.WHITE)
		return

	var y: float = float(font_size)
	var prefix_w: float = font.get_string_size(prefix, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
	draw_string(font, Vector2(start_x, y), prefix, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size, Color.WHITE)

	var x: float = start_x + prefix_w
	for i: int in range(_digits_text.length()):
		var ch: String = _digits_text.substr(i, 1)
		var pulse_left: float = float(_pulse_by_digit_idx.get(i, 0.0))
		var k: float = pulse_left / maxf(0.0001, pulse_duration_s)
		var amp: float = 1.0 + 0.18 * sin((1.0 - k) * PI) * k
		var c: Color = Color(1.0, 1.0 - 0.12 * k, 1.0 - 0.12 * k, 1.0)
		var char_size: int = int(round(float(font_size) * amp))
		var y_off: float = -2.0 * k
		draw_string(font, Vector2(x, y + y_off), ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, char_size, c)
		x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size).x
