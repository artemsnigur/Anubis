shader_type spatial;
// Death effect: the body turns to sand and crumbles away from the top down,
// with a glowing ember edge at the dissolve front.
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley;

uniform vec4 sand_color : source_color = vec4(0.72, 0.56, 0.34, 1.0);
uniform vec4 edge_color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float progress = 0.0;
uniform float base_y = 0.0;
uniform float height = 2.0;

varying vec3 wpos;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float vnoise(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x), mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x), mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float h = clamp((wpos.y - base_y) / max(height, 0.01), 0.0, 1.0);
	float n = vnoise(wpos * 7.0) * 0.55 + vnoise(wpos * 17.0) * 0.25;
	// Higher parts go first: threshold rises from the top.
	float v = n * 0.6 + (1.0 - h) * 0.6;
	float cut = progress * 1.25;
	if (v < cut) {
		discard;
	}
	float edge = 1.0 - smoothstep(0.0, 0.06, v - cut);
	ALBEDO = sand_color.rgb * (0.75 + 0.5 * n);
	ROUGHNESS = 1.0;
	EMISSION = edge_color.rgb * edge * 3.0 * step(0.001, progress);
}
