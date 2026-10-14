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
uniform float normal_strength = 1.0;
// Desert sand: wind ripples (normal + shading) and view-dependent glitter.
uniform float ripple_strength = 0.0;
uniform float ripple_scale = 1.6;
uniform float glitter = 0.0;
// Tomb paintings: glyphs coloured with mineral pigments, khekher frieze above them.
uniform bool glyph_painted = false;
uniform float frieze = 0.0;
// Carved rock blocks: top faces use a different colour (desert / rock cap).
uniform float top_mix = 0.0;
uniform vec4 top_color : source_color = vec4(0.82, 0.68, 0.46, 1.0);

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

vec3 pigment(float h) {
	// Egyptian mineral palette: lapis, malachite, red ochre, carbon black, orpiment yellow.
	if (h < 0.28) return vec3(0.08, 0.2, 0.55);
	if (h < 0.5) return vec3(0.12, 0.45, 0.32);
	if (h < 0.72) return vec3(0.62, 0.16, 0.08);
	if (h < 0.86) return vec3(0.05, 0.04, 0.04);
	return vec3(0.85, 0.62, 0.15);
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
	vec3 em = emission_color.rgb * emission_energy;
	// Wind-blown sand settling on upward faces.
	float sand = sand_cover * smoothstep(0.55, 0.95, n.y) * smoothstep(0.3, 0.7, big);
	col = mix(col, grout_color.rgb, grout * 0.85);
	col = mix(col, sand_color.rgb, sand);
	if (top_mix > 0.0 && n.y > 0.7) {
		col = mix(col, top_color.rgb * (0.8 + 0.35 * t), top_mix);
		rough = mix(rough, 0.95, top_mix);
	}
	vec3 ripple_n = vec3(0.0);
	if (ripple_strength > 0.0 && n.y > 0.7) {
		// Wind ripples: warped sine bands, sharper on the lee side.
		vec2 p = world_pos.xz * ripple_scale;
		float warp = big * 5.0 + fine * 0.8;
		float phase = dot(p, vec2(0.82, 0.57)) * 6.2831 + warp;
		float w = sin(phase);
		float crest = pow(0.5 + 0.5 * w, 3.0);
		col *= 1.0 - ripple_strength * 0.16 * (1.0 - crest);
		float dw = cos(phase) * ripple_strength;
		ripple_n = vec3(0.82, 0.0, 0.57) * dw;
	}
	if (glitter > 0.0 && n.y > 0.5) {
		vec2 gp = floor(world_pos.xz * 55.0);
		float gh = fract(sin(dot(gp, vec2(12.9898, 78.233))) * 43758.5453);
		float view_h = fract(sin(dot(floor(VIEW.xz * 6.0 + gp * 0.01), vec2(39.3, 11.7))) * 1931.7);
		float g = step(0.996, gh) * step(0.6, view_h);
		em += vec3(1.0, 0.9, 0.7) * g * glitter * 2.5;
	}
	// Carved hieroglyph band on vertical faces.
	vec2 guv = abs(n.x) > abs(n.z) ? world_pos.zy : world_pos.xy;
	if (glyph_strength > 0.0 && abs(n.y) < 0.3 && world_pos.y > glyph_band_min && world_pos.y < glyph_band_max) {
		float g = texture(glyph_tex, guv * glyph_scale).r;
		float band = smoothstep(glyph_band_min, glyph_band_min + 0.08, world_pos.y) * (1.0 - smoothstep(glyph_band_max - 0.08, glyph_band_max, world_pos.y));
		float gm = g * glyph_strength * band;
		vec3 gc = glyph_color.rgb;
		if (glyph_painted) {
			// One pigment per glyph cell of the atlas (8 columns, ~9 rows per texture tile).
			vec2 cell = floor(guv * glyph_scale * vec2(8.0, 9.0));
			gc = pigment(fract(sin(dot(cell, vec2(41.7, 289.3))) * 9381.13));
			gc *= 0.8 + 0.4 * fine;
		}
		col = mix(col, gc, gm);
		em += gc * gm * glyph_emission;
		rough = mix(rough, 0.6, gm);
	}
	if (frieze > 0.0 && abs(n.y) < 0.3) {
		float fy = world_pos.y - glyph_band_max;
		if (fy > 0.06 && fy < 0.46) {
			float along = (abs(n.x) > abs(n.z) ? world_pos.z : world_pos.x) * 4.0;
			float bar = fract(along);
			float idx = mod(floor(along), 3.0);
			vec3 fc = idx < 1.0 ? vec3(0.62, 0.16, 0.08) : (idx < 2.0 ? vec3(0.08, 0.2, 0.55) : vec3(0.12, 0.45, 0.32));
			float shape = smoothstep(0.08, 0.14, bar) * (1.0 - smoothstep(0.86, 0.92, bar)) * smoothstep(0.06, 0.1, fy) * (1.0 - smoothstep(0.34, 0.4, fy));
			float line = (1.0 - smoothstep(0.0, 0.03, abs(fy - 0.06))) + (1.0 - smoothstep(0.0, 0.03, abs(fy - 0.44)));
			col = mix(col, fc, shape * frieze);
			col = mix(col, vec3(0.05, 0.04, 0.03), clamp(line, 0.0, 1.0) * frieze);
		}
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	METALLIC = metal;
	SPECULAR = specular_value;
	EMISSION = em;
	// Cheap normal perturbation from the noise for a chiselled look.
	NORMAL_MAP = vec3(0.5 + (fine - 0.5) * 0.35 * normal_strength + ripple_n.x * 0.35, 0.5 + (big - 0.5) * 0.35 * normal_strength + ripple_n.z * 0.35, 1.0);
	NORMAL_MAP_DEPTH = 0.6;
}
