shader_type spatial;
// Turquoise faience with gold veins (the ushabti hero): glossy glaze, tonal variation,
// and a kintsugi-like network of gold cracks from 3D Voronoi cell edges.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec4 base_color : source_color = vec4(0.13, 0.55, 0.52, 1.0);
uniform vec4 deep_color : source_color = vec4(0.03, 0.27, 0.31, 1.0);
uniform vec4 vein_color : source_color = vec4(1.0, 0.74, 0.27, 1.0);
uniform float vein_scale = 5.5;
uniform float vein_width = 0.07;
uniform float glaze_roughness = 0.2;
uniform float vein_glow = 0.45;
uniform float damage = 0.0;

varying vec3 obj_pos;

vec3 hash33(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return fract(sin(p) * 43758.5453123);
}

// Returns F2 - F1 (distance to the nearest cell edge, roughly).
float voronoi_edge(vec3 x) {
	vec3 i = floor(x);
	vec3 f = fract(x);
	float f1 = 8.0;
	float f2 = 8.0;
	for (int k = -1; k <= 1; k++) {
		for (int j = -1; j <= 1; j++) {
			for (int n = -1; n <= 1; n++) {
				vec3 g = vec3(float(n), float(j), float(k));
				vec3 o = hash33(i + g);
				vec3 r = g + o - f;
				float d = dot(r, r);
				if (d < f1) {
					f2 = f1;
					f1 = d;
				} else if (d < f2) {
					f2 = d;
				}
			}
		}
	}
	return sqrt(f2) - sqrt(f1);
}

float hash13(vec3 p) {
	return fract(sin(dot(p, vec3(12.9898, 78.233, 37.719))) * 43758.5453);
}

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	vec3 p = obj_pos * vein_scale;
	float e = voronoi_edge(p);
	float w = vein_width * (1.0 + damage * 1.5);
	float vein = 1.0 - smoothstep(w * 0.5, w, e);
	float tone = hash13(floor(p * 0.7)) * 0.35 + 0.65 * smoothstep(0.0, 0.6, e);
	vec3 col = mix(deep_color.rgb, base_color.rgb, clamp(tone, 0.0, 1.0));
	ALBEDO = mix(col, vein_color.rgb, vein);
	METALLIC = vein * 0.9;
	ROUGHNESS = mix(glaze_roughness, 0.3, vein);
	SPECULAR = 0.6;
	CLEARCOAT = 0.7 * (1.0 - vein);
	CLEARCOAT_ROUGHNESS = 0.12;
	EMISSION = vein_color.rgb * vein * vein_glow;
	RIM = 0.3;
	RIM_TINT = 0.5;
}
