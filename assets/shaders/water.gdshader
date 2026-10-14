shader_type spatial;
// Reflecting pool: turquoise water with two scrolling ripple layers, fresnel and sun glints.
render_mode blend_mix, depth_draw_opaque, cull_back, specular_schlick_ggx;

uniform vec4 deep_color : source_color = vec4(0.02, 0.17, 0.2, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.1, 0.45, 0.42, 1.0);
uniform vec4 sky_tint : source_color = vec4(0.55, 0.7, 0.85, 1.0);
uniform sampler2D noise_tex : hint_default_white, filter_linear_mipmap, repeat_enable;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 uv1 = wpos.xz * 0.22 + TIME * vec2(0.018, 0.012);
	vec2 uv2 = wpos.xz * 0.41 - TIME * vec2(0.012, 0.02);
	float a = texture(noise_tex, uv1).r;
	float b = texture(noise_tex, uv2).r;
	vec2 slope = vec2(a - 0.5, b - 0.5);
	NORMAL_MAP = vec3(0.5 + slope.x * 0.5, 0.5 + slope.y * 0.5, 1.0);
	NORMAL_MAP_DEPTH = 0.3;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 col = mix(deep_color.rgb, shallow_color.rgb, clamp(a * 0.6 + 0.2, 0.0, 1.0));
	ALBEDO = mix(col, sky_tint.rgb, fres * 0.6);
	ROUGHNESS = 0.12;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	EMISSION = shallow_color.rgb * 0.05;
}
