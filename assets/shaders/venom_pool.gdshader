shader_type spatial;
// Poison puddle: dark glossy green liquid with a glowing rim, slow swirl and popping bubbles.
render_mode blend_mix, depth_draw_never, cull_back, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.03, 0.12, 0.03, 1.0);
uniform vec4 bright_color : source_color = vec4(0.45, 0.95, 0.2, 1.0);
uniform float fade = 1.0;
uniform float seed = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	// Irregular blob edge.
	float edge = 0.82 + 0.16 * vnoise(vec2(atan(c.y, c.x) * 2.0 + seed, seed));
	if (r > edge) {
		discard;
	}
	float t = TIME * 0.4 + seed;
	float n = vnoise(c * 3.0 + vec2(t, -t * 0.7)) * 0.6 + vnoise(c * 7.0 - vec2(t * 1.3, t)) * 0.4;
	float rim = smoothstep(edge - 0.18, edge, r);
	// Bubbles: cells that pop on a timer.
	vec2 cell = floor(c * 6.0);
	float h = hash(cell + seed);
	float life = fract(TIME * (0.3 + h * 0.5) + h * 7.0);
	vec2 cpos = (cell + 0.5 + (vec2(hash(cell + 3.1), hash(cell + 7.7)) - 0.5) * 0.5) / 6.0;
	float bubble = (1.0 - smoothstep(0.0, 0.035 * life + 0.005, length(c - cpos))) * step(0.55, h) * (1.0 - life);
	vec3 col = mix(deep_color.rgb, bright_color.rgb * 0.6, n * 0.5 + rim * 0.7);
	ALBEDO = col;
	ROUGHNESS = 0.08;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	EMISSION = bright_color.rgb * (rim * 0.9 + bubble * 1.5 + n * 0.15) * fade;
	ALPHA = (0.92 - rim * 0.3) * fade;
}
