shader_type canvas_item;
render_mode blend_mix;

/// Darker of the two duotone colors.
uniform vec4 base_color : source_color = vec4(0.008, 0.015, 0.05, 1.0);
/// Brighter of the two duotone colors.
uniform vec4 base_color_bottom : source_color = vec4(0.03, 0.06, 0.14, 1.0);
uniform float time = 0.0;
/// Width / height of the rect (keeps ripples circular, not elliptical).
uniform float aspect : hint_range(0.2, 4.0) = 0.78;

void fragment() {
	vec2 uv0 = UV - vec2(0.5);
	uv0.x *= aspect;
	float r = length(uv0);
	float ang = atan(uv0.y, uv0.x);

	float t = time;

	// Concentric ripples (wild loop–style motion)
	float rip = sin(r * 19.0 - t * 3.1) * 0.5 + 0.5;
	rip += sin(r * 31.0 + t * 2.4) * 0.32;
	rip += sin(r * 9.0 - t * 1.6) * 0.18;
	rip = clamp(rip / 1.5, 0.0, 1.0);

	// Spiral / psychedelic interference
	float sp = sin(ang * 7.0 + r * 24.0 - t * 4.2) * 0.5 + 0.5;
	sp += sin(ang * 5.0 - r * 18.0 + t * 3.0) * 0.35;
	sp = clamp(sp / 1.35, 0.0, 1.0);

	// Slow screen-space waves
	vec2 pq = UV * vec2(11.5, 11.0);
	float w1 = sin(pq.x + sin(pq.y * 0.8 + t * 0.6) + t * 0.95);
	float w2 = cos(pq.y * 1.1 - pq.x * 0.7 - t * 0.85);
	float waves = (w1 * w2) * 0.5 + 0.5;

	// Mild domain warp (“distortion”) — re-sample ripples in warped space
	vec2 warp = vec2(
			sin(UV.y * 9.2 + t * 0.75) + sin(UV.x * 6.1 - t * 0.5),
			cos(UV.x * 8.4 + t * 0.68) + cos(UV.y * 7.3 - t * 0.42)
	) * 0.035;
	vec2 u_w = UV + warp - vec2(0.5);
	u_w.x *= aspect;
	float r_w = length(u_w);
	float rip_w = sin(r_w * 22.0 - t * 3.4) * 0.5 + 0.5;

	// Combine into single 0..1 mask (duotone mix factor)
	float m = rip * 0.26 + sp * 0.28 + waves * 0.22 + rip_w * 0.24;
	m = clamp(m, 0.0, 1.0);
	// Soften harsh edges between bands
	m = smoothstep(0.12, 0.88, m);

	vec3 col = mix(base_color.rgb, base_color_bottom.rgb, m);
	COLOR = vec4(col, base_color.a);
}
