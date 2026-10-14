shader_type spatial;
// Curtain of falling sand (boss arena gate). Scrolling streaks + noise.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 sand_color : source_color = vec4(0.95, 0.74, 0.42, 1.0);
uniform float density = 1.0;
uniform float speed = 1.6;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	float col_id = floor(uv.x * 90.0);
	float offs = hash(vec2(col_id, 1.0));
	float streak = fract(uv.y * 3.0 - TIME * speed * (0.7 + offs) + offs * 7.0);
	float s = smoothstep(0.0, 0.6, streak) * (0.4 + 0.6 * hash(vec2(col_id, 4.0)));
	float edge = smoothstep(0.0, 0.08, uv.x) * smoothstep(1.0, 0.92, uv.x) * smoothstep(1.0, 0.85, uv.y);
	float a = clamp((0.12 + s * 0.75) * edge * density, 0.0, 1.0);
	ALBEDO = sand_color.rgb * (0.8 + 0.5 * s);
	ALPHA = a * 0.7;
}
