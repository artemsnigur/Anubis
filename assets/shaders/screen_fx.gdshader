shader_type canvas_item;
// Full-screen post effects on top of the 3D view (under the HUD):
// vignette, warm/cool grade, film grain, chromatic aberration pulse on hits,
// pulsing red edges at low health and a white-gold flash for big moments.

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap;
uniform float vignette = 0.32;
uniform vec4 grade_shadows : source_color = vec4(0.92, 0.95, 1.06, 1.0);
uniform vec4 grade_highlights : source_color = vec4(1.06, 1.0, 0.92, 1.0);
uniform float grain = 0.025;
uniform float aberration = 0.0;
uniform float low_health = 0.0;
uniform float hurt = 0.0;
uniform float desaturate = 0.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 c = uv - 0.5;
	float r = length(c * vec2(1.4, 1.0));
	vec3 col;
	if (aberration > 0.0005) {
		vec2 off = c * aberration;
		col.r = texture(screen_tex, uv + off).r;
		col.g = texture(screen_tex, uv).g;
		col.b = texture(screen_tex, uv - off).b;
	} else {
		col = texture(screen_tex, uv).rgb;
	}
	float lum = dot(col, vec3(0.299, 0.587, 0.114));
	col *= mix(grade_shadows.rgb, grade_highlights.rgb, smoothstep(0.15, 0.75, lum));
	col = mix(col, vec3(lum), desaturate);
	col *= 1.0 - vignette * smoothstep(0.38, 1.05, r);
	float edge = smoothstep(0.35, 1.0, r);
	float pulse = 0.6 + 0.4 * sin(TIME * 5.5);
	col = mix(col, vec3(0.45, 0.02, 0.0), clamp(low_health * edge * pulse + hurt * edge * 0.8, 0.0, 0.85));
	col += (hash(uv * 731.0 + fract(TIME * 7.0)) - 0.5) * grain;
	COLOR = vec4(col, 1.0);
}
