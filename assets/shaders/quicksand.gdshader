shader_type spatial;
// Swirling quicksand pool (Ammit phase 2).
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley;

uniform vec4 sand_a : source_color = vec4(0.70, 0.52, 0.28, 1.0);
uniform vec4 sand_b : source_color = vec4(0.42, 0.29, 0.14, 1.0);
uniform float strength = 1.0;
uniform float swirl_speed = 0.6;

float hash(vec2 p) { return fract(sin(dot(p, vec2(41.3, 289.1))) * 15731.743); }
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	float ang = atan(c.y, c.x) + TIME * swirl_speed * (1.5 - r) + r * 6.0;
	vec2 p = vec2(cos(ang), sin(ang)) * r * 5.0;
	float n = vnoise(p + TIME * 0.2) * 0.6 + vnoise(p * 2.7) * 0.4;
	vec3 col = mix(sand_b.rgb, sand_a.rgb, n);
	float rim = smoothstep(0.75, 1.0, r);
	ALBEDO = mix(col * (0.75 + 0.25 * strength), sand_a.rgb, rim * 0.5);
	ROUGHNESS = 1.0;
	if (r > 1.0) {
		discard;
	}
}
