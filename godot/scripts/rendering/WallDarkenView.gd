extends Node2D

const CELL_PX: float = 18.0

const SIDE_CLEAR_DARK_MAX: float = 0.45
const SIDE_CLEAR_SEAM_FALLOFF_TILES: float = 3.0

var _model: RefCounted = null
var _mask_tex: Texture2D = null
var _sprite: Sprite2D = null
var _shader_mat: ShaderMaterial = null

func set_model(m: RefCounted) -> void:
	_model = m
	_update_uniforms()

func set_wall_mask(mask_tex: Texture2D) -> void:
	_mask_tex = mask_tex
	_update_uniforms()

func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.centered = false
	add_child(_sprite)

	var sh: Shader = Shader.new()
	sh.code = """
shader_type canvas_item;
render_mode blend_mul;

uniform sampler2D wall_mask;
uniform float left_prog = 0.0;
uniform float right_prog = 0.0;
uniform float dark_max = 0.45;
uniform float seam_falloff_tiles = 3.0;
uniform vec2 board_tiles = vec2(28.0, 36.0);
uniform float time_s = 0.0;

void fragment() {
	vec2 uv = UV;
	float a = texture(wall_mask, uv).a;
	if (a <= 0.001) { a = 0.0; }
	float x_tiles = uv.x * board_tiles.x;
	float dist = abs(x_tiles - 13.5);
	float seam_mix = 1.0 - clamp(dist / max(0.0001, seam_falloff_tiles), 0.0, 1.0);
	float prog = (x_tiles < 14.0) ? left_prog : right_prog;
	float other_prog = (x_tiles < 14.0) ? right_prog : left_prog;
	float near_prog = min(prog, other_prog);
	float far_dark = dark_max * prog;
	float near_dark = dark_max * near_prog;
	float dark = mix(far_dark, near_dark, seam_mix);
	float ambient = 0.04 * (0.5 + 0.5 * sin(time_s * 1.4 + x_tiles * 0.18));
	dark += ambient;
	float m = 1.0 - (dark * a);
	COLOR = vec4(m, m, m, 1.0);
}
"""
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = sh
	_sprite.material = _shader_mat

	_update_sprite_size()

func _process(_delta: float) -> void:
	_update_uniforms()

func _update_sprite_size() -> void:
	# Create a 1x1 dummy texture; shader uses UV so size matters only for mapping.
	var img: Image = Image.create(28 * int(CELL_PX), 36 * int(CELL_PX), false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	_sprite.texture = ImageTexture.create_from_image(img)

func _update_uniforms() -> void:
	if _shader_mat == null:
		return
	if _mask_tex != null:
		_shader_mat.set_shader_parameter("wall_mask", _mask_tex)
	if _model != null:
		_shader_mat.set_shader_parameter("left_prog", float(_model.get("left_side_clear_progress")))
		_shader_mat.set_shader_parameter("right_prog", float(_model.get("right_side_clear_progress")))
		_shader_mat.set_shader_parameter("time_s", 600.0 - float(_model.get("time_remaining_s")))
	_shader_mat.set_shader_parameter("dark_max", SIDE_CLEAR_DARK_MAX)
	_shader_mat.set_shader_parameter("seam_falloff_tiles", SIDE_CLEAR_SEAM_FALLOFF_TILES)

