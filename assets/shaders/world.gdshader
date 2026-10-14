shader_type spatial;
// Uber shader for level geometry: triplanar noise (sandstone, lapis, basalt, terracotta, gold),
// optional strata, gold flecks, a carved hieroglyph band, and dithered occlusion fade:
// fragments between the camera and the player are discarded with a Bayer pattern
// (no alpha blending -> no sorting problems).
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

global uniform vec3 player_position;
global uniform float occlusion_radius;
global uniform float occlusion_enabled;

uniform vec4 color_a : source_color = vec4(0.78, 0.62, 0.40, 1.0);
uniform vec4 color_b : source_color = vec4(0.62, 0.46, 0.28, 1.0);
uniform vec4 accent_color : source_color = vec4(0.95, 0.75, 0.30, 1.0);
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;
uniform float tex_scale = 0.18;
uniform float detail_scale = 1.1;
uniform float strata_strength = 0.18;
uniform float strata_scale = 2.6;
uniform float fleck_amount = 0.0;
uniform float roughness_value : hint_range(0.0, 1.0) = 0.88;
uniform float metallic_value : hint_range(0.0, 1.0) = 0.0;
uniform float specular_value : hint_range(0.0, 1.0) = 0.35;
uniform sampler2D glyph_tex : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform float glyph_strength = 0.0;
uniform float glyph_band_min = 0.7;
uniform float glyph_band_max = 2.9;
uniform float glyph_scale = 0.42;
uniform vec4 glyph_color : source_color = vec4(0.30, 0.17, 0.08, 1.0);
uniform float glyph_emission = 0.0;
uniform bool occluder = true;
uniform float occlusion_floor_offset = 0.35;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float sand_cover = 0.0;
uniform vec4 sand_color : source_color = vec4(0.86, 0.70, 0.45, 1.0);
// Paving: grout grid on upward faces (0 = off), per-slab tint variation.
uniform float tile_size = 0.0;
uniform vec4 grout_color : source_color = vec4(0.35, 0.27, 0.18, 1.0);
uniform float tile_variation = 0.18;
uniform float noise_contrast = 1.0;

varying vec3 world_pos;
varying vec3 world_normal;

vec4 triplanar(sampler2D tex, vec3 p, vec3 n, float scale) {
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z + 0.0001);
	return texture(tex, p.zy * scale) * w.x + texture(tex, p.xz * scale) * w.y + texture(tex, p.xy * scale) * w.z;
}

float bayer4(vec2 fc) {
	int x = int(mod(fc.x, 4.0));
	int y = int(mod(fc.y, 4.0));
	int idx = x + y * 4;
	float m[16] = float[16](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
	return (m[idx] + 0.5) / 16.0;
}

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	if (occluder && occlusion_enabled > 0.5 && world_pos.y > player_position.y + occlusion_floor_offset) {
		vec3 pv = (VIEW_MATRIX * vec4(player_position + vec3(0.0, 1.0, 0.0), 1.0)).xyz;
		bool ortho = PROJECTION_MATRIX[3][3] > 0.5;
		float d;
		if (ortho) {
			d = length(VERTEX.xy - pv.xy) / 14.0;
		} else {
			d = length(VERTEX.xy / -VERTEX.z - pv.xy / -pv.z);
		}
		bool in_front = -VERTEX.z < -pv.z - 0.6;
		if (in_front) {
			float r = occlusion_radius;
			float fade = 1.0 - smoothstep(r * 0.55, r, d);
			if (bayer4(FRAGCOORD.xy) < fade * 0.88) {
				discard;
			}
		}
	}

	vec3 n = normalize(world_normal);
	float big = triplanar(noise_tex, world_pos, n, tex_scale).r;
	float fine = triplanar(noise_tex, world_pos, n, detail_scale).r;
	float t = clamp(big * 0.7 + fine * 0.3, 0.0, 1.0);
	t = clamp(0.5 + (t - 0.5) * noise_contrast, 0.0, 1.0);
	vec3 col = mix(color_b.rgb, color_a.rgb, smoothstep(0.25, 0.75, t));
	float grout = 0.0;
	if (tile_size > 0.0 && n.y > 0.6) {
		vec2 tp = world_pos.xz / tile_size;
		// Running bond: offset every other row.
		tp.x += step(1.0, mod(floor(tp.y), 2.0)) * 0.5;
		vec2 cell = floor(tp);
		vec2 f = fract(tp);
		float h = fract(sin(dot(cell, vec2(12.9898, 78.233))) * 43758.5453);
		col *= 1.0 - tile_variation * 0.5 + tile_variation * h;
		float edge = min(min(f.x, 1.0 - f.x), min(f.y, 1.0 - f.y));
		grout = 1.0 - smoothstep(0.015, 0.04, edge + (fine - 0.5) * 0.02);
	}
	// Horizontal sediment strata on vertical faces.
	float strata = sin(world_pos.y * strata_scale * 6.2831 + big * 4.0) * 0.5 + 0.5;
	col *= 1.0 - strata_strength * strata * (1.0 - abs(n.y));
	// Gold flecks (lapis lazuli pyrite).
	float fleck = smoothstep(0.86, 0.9, fine) * fleck_amount;
	col = mix(col, accent_color.rgb, fleck);
	float metal = mix(metallic_value, 1.0, fleck);
	float rough = mix(roughness_value, 0.3, fleck);
	// Wind-blown sand settling on upward faces.
	float sand = sand_cover * smoothstep(0.55, 0.95, n.y) * smoothstep(0.3, 0.7, big);
	col = mix(col, grout_color.rgb, grout * 0.85);
	col = mix(col, sand_color.rgb, sand);
	// Carved hieroglyph band on vertical faces.
	vec3 em = emission_color.rgb * emission_energy;
	if (glyph_strength > 0.0 && abs(n.y) < 0.3 && world_pos.y > glyph_band_min && world_pos.y < glyph_band_max) {
		vec2 guv = abs(n.x) > abs(n.z) ? world_pos.zy : world_pos.xy;
		float g = texture(glyph_tex, guv * glyph_scale).r;
		float band = smoothstep(glyph_band_min, glyph_band_min + 0.08, world_pos.y) * (1.0 - smoothstep(glyph_band_max - 0.08, glyph_band_max, world_pos.y));
		float gm = g * glyph_strength * band;
		col = mix(col, glyph_color.rgb, gm);
		em += glyph_color.rgb * gm * glyph_emission;
		rough = mix(rough, 0.6, gm);
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = specular_value;
	EMISSION = em;
	// Cheap normal perturbation from the noise for a chiselled look.
	NORMAL_MAP = vec3(0.5 + (fine - 0.5) * 0.35, 0.5 + (big - 0.5) * 0.35, 1.0);
	NORMAL_MAP_DEPTH = 0.6;
}
