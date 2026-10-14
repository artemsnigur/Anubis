shader_type spatial;
// Turquoise faience with gold veins (the ushabti hero). Glossy glaze, procedural cracks.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.12, 0.62, 0.62, 1.0);
uniform vec4 deep_color : source_color = vec4(0.04, 0.32, 0.38, 1.0);
uniform vec4 vein_color : source_color = vec4(1.0, 0.76, 0.28, 1.0);
uniform float vein_scale = 3.2;
uniform float vein_width = 0.055;
uniform float glaze_roughness = 0.22;
uniform float vein_glow = 0.35;
uniform float damage = 0.0; // 0..1, more cracks when hurt

varying vec3 obj_pos;

float hash3(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

float noise3(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash3(i + vec3(0, 0, 0)), hash3(i + vec3(1, 0, 0)), f.x),
				   mix(hash3(i + vec3(0, 1, 0)), hash3(i + vec3(1, 1, 0)), f.x), f.y),
			   mix(mix(hash3(i + vec3(0, 0, 1)), hash3(i + vec3(1, 0, 1)), f.x),
				   mix(hash3(i + vec3(0, 1, 1)), hash3(i + vec3(1, 1, 1)), f.x), f.y), f.z);
}

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	vec3 p = obj_pos * vein_scale;
	float n = noise3(p) * 0.6 + noise3(p * 2.3) * 0.3 + noise3(p * 5.1) * 0.1;
	// Veins = thin bands around the noise iso-line.
	float v = abs(n - 0.5);
	float width = vein_width * (1.0 + damage * 1.5);
	float vein = 1.0 - smoothstep(width * 0.4, width, v);
	float tone = noise3(obj_pos * 9.0);
	vec3 col = mix(deep_color.rgb, base_color.rgb, 0.55 + 0.45 * tone);
	ALBEDO = mix(col, vein_color.rgb, vein);
	METALLIC = vein * 0.9;
	ROUGHNESS = mix(glaze_roughness, 0.35, vein);
	SPECULAR = 0.6;
	CLEARCOAT = 0.6 * (1.0 - vein);
	CLEARCOAT_ROUGHNESS = 0.15;
	EMISSION = vein_color.rgb * vein * vein_glow;
	RIM = 0.25;
	RIM_TINT = 0.6;
}
