extends Node2D

## Stronger than 1.0 so additive ghost tint reads on walls (matches web visibility better).
const GHOST_LIGHT_ALPHA_MAX: float = 2.0
const GHOST_LIGHT_RADIUS_TILES: float = 4.2
## Extra saturation for fear blue (sprite palette is muted).
const GHOST_FEAR_BLUE_SAT: float = 1.38
const PAC_LIGHT_ALPHA_MAX: float = 1.1

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
render_mode blend_add;

uniform sampler2D wall_mask;
uniform vec2 board_tiles = vec2(28.0, 36.0);
uniform float easing_exp = 0.35;

uniform vec2 pac_pos = vec2(0.0);
uniform float pac_radius = 5.0;
uniform float pac_alpha = 0.85;

uniform vec2 ghost_pos0 = vec2(0.0);
uniform vec2 ghost_pos1 = vec2(0.0);
uniform vec2 ghost_pos2 = vec2(0.0);
uniform vec2 ghost_pos3 = vec2(0.0);

uniform vec3 ghost_col0 = vec3(1.0);
uniform vec3 ghost_col1 = vec3(1.0);
uniform vec3 ghost_col2 = vec3(1.0);
uniform vec3 ghost_col3 = vec3(1.0);

uniform float ghost_radius = 3.0;
uniform float ghost_alpha = 1.0;

float eased_falloff(float d, float r, float amax, float expv) {
	float t = clamp(d / max(0.0001, r), 0.0, 1.0);
	return amax * (1.0 - pow(t, max(0.0001, expv)));
}

vec2 torus_delta(vec2 a, vec2 b, vec2 size) {
	vec2 d = a - b;
	vec2 ad = abs(d);
	vec2 w = size - ad;
	return vec2( (w.x < ad.x) ? -sign(d.x) * w.x : d.x,
	             (w.y < ad.y) ? -sign(d.y) * w.y : d.y );
}

void fragment() {
	float mask_a = texture(wall_mask, UV).a;
	if (mask_a <= 0.001) { mask_a = 0.0; }
	vec2 cell = vec2(UV.x * board_tiles.x, UV.y * board_tiles.y);

	// Pac light (white)
	vec2 dp = torus_delta(cell, pac_pos, board_tiles);
	float ap = eased_falloff(length(dp), pac_radius, pac_alpha, easing_exp);
	vec3 rgb = vec3(1.0) * ap;

	// Ghost lights (colored)
	vec2 d0 = torus_delta(cell, ghost_pos0, board_tiles);
	vec2 d1 = torus_delta(cell, ghost_pos1, board_tiles);
	vec2 d2 = torus_delta(cell, ghost_pos2, board_tiles);
	vec2 d3 = torus_delta(cell, ghost_pos3, board_tiles);
	float a0 = eased_falloff(length(d0), ghost_radius, ghost_alpha, easing_exp);
	float a1 = eased_falloff(length(d1), ghost_radius, ghost_alpha, easing_exp);
	float a2 = eased_falloff(length(d2), ghost_radius, ghost_alpha, easing_exp);
	float a3 = eased_falloff(length(d3), ghost_radius, ghost_alpha, easing_exp);

	rgb += ghost_col0 * a0;
	rgb += ghost_col1 * a1;
	rgb += ghost_col2 * a2;
	rgb += ghost_col3 * a3;

	COLOR = vec4(rgb, 1.0) * mask_a;
}
"""
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = sh
	_shader_mat.set_shader_parameter("ghost_alpha", GHOST_LIGHT_ALPHA_MAX)
	_shader_mat.set_shader_parameter("ghost_radius", GHOST_LIGHT_RADIUS_TILES)
	_sprite.material = _shader_mat

	_update_sprite_size()

func _process(_delta: float) -> void:
	_update_uniforms()

func _update_sprite_size() -> void:
	var img: Image = Image.create(28 * 18, 36 * 18, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 1, 1, 1))
	_sprite.texture = ImageTexture.create_from_image(img)

func _update_uniforms() -> void:
	if _shader_mat == null:
		return
	if _mask_tex != null:
		_shader_mat.set_shader_parameter("wall_mask", _mask_tex)
	if _model == null:
		return

	var pac: Vector2 = _model.get("pac_pos") as Vector2
	_shader_mat.set_shader_parameter("pac_pos", Vector2(pac.x, pac.y))
	_shader_mat.set_shader_parameter("pac_alpha", PAC_LIGHT_ALPHA_MAX)
	var t: float = Constants.LEVEL_DURATION_S - float(_model.get("time_remaining_s"))
	var ambient_mul: float = 0.92 + 0.08 * (0.5 + 0.5 * sin(t * 1.2))
	_shader_mat.set_shader_parameter("ghost_alpha", GHOST_LIGHT_ALPHA_MAX * ambient_mul)
	_shader_mat.set_shader_parameter("ghost_radius", GHOST_LIGHT_RADIUS_TILES)

	# Ghost positions/colors — match GhostsView (fear / incap); no wall tint while incapacitated.
	var ghosts_v: Variant = _model.get("ghosts")
	if typeof(ghosts_v) == TYPE_ARRAY:
		var ghosts: Array = ghosts_v as Array
		for i: int in range(min(4, ghosts.size())):
			var g: RefCounted = ghosts[i] as RefCounted
			var from: Vector2i = g.get("anim_from") as Vector2i
			var to: Vector2i = g.get("anim_to") as Vector2i
			var anim_t: float = float(g.get("anim_t"))
			var gvf: Vector2 = GhostInterpolation.visual_center_fractional(from, to, anim_t, 28, 36)
			var pos: Vector2 = Vector2(fposmod(gvf.x, 28.0), fposmod(gvf.y, 36.0))
			_shader_mat.set_shader_parameter("ghost_pos%d" % i, pos)

			var id: String = g.get("id") as String
			var col: Color = _ghost_light_color_for_ghost(id, g)
			_shader_mat.set_shader_parameter("ghost_col%d" % i, Vector3(col.r, col.g, col.b))

## Wall lights: warm red/orange (not neon R or red-heavy “peach”), still readable under blend_add + Pac white.
func _wall_light_tint_for_id(id: String) -> Color:
	if id == "red":
		# Slightly more green than blue → warm brick; avoids sRGB “pure red” / hot magenta read.
		return Color(0.78, 0.17, 0.11, 1.0)
	if id == "pink":
		return Color(0.98, 0.22, 0.62, 1.0)
	if id == "blue":
		return Color(0.02, 0.72, 0.98, 1.0)
	if id == "orange":
		# ~#EA8208: strong G vs B so additive white stays amber, not pink/peach.
		return Color(0.92, 0.51, 0.03, 1.0)
	return Color(0.55, 0.55, 0.58, 1.0)

func _saturate_toward_hue(c: Color, strength: float) -> Color:
	var l: float = 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
	return Color(
		clampf(l + (c.r - l) * strength, 0.0, 1.0),
		clampf(l + (c.g - l) * strength, 0.0, 1.0),
		clampf(l + (c.b - l) * strength, 0.0, 1.0),
		c.a
	)

func _ghost_light_color_for_ghost(id: String, g: RefCounted) -> Color:
	# Shader does `rgb += ghost_col * falloff` — zero color removes light completely.
	if bool(g.get("is_incapacitated")):
		return Color(0, 0, 0, 1)

	var fear_ms: float = float(_model.get("fear_ms"))
	var c: Color
	if fear_ms <= 0.0:
		c = _wall_light_tint_for_id(id)
	elif fear_ms > 2000.0:
		c = _saturate_toward_hue(Color(0.117, 0.227, 0.541, 1.0), GHOST_FEAR_BLUE_SAT)
	else:
		var flash_on: bool = int(floor(fear_ms / 150.0)) % 2 == 0
		if flash_on:
			# Pure white flash (no pink cast).
			c = Color(1, 1, 1, 1)
		else:
			c = _saturate_toward_hue(Color(0.117, 0.227, 0.541, 1.0), GHOST_FEAR_BLUE_SAT)
	return c
