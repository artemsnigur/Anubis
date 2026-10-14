shader_type spatial;
// Animated fire on a Y-axis billboard quad: fbm-distorted teardrop with a white-hot core,
// orange body and red edge. Additive, so it blooms through the glow pass.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color_core : source_color = vec4(1.0, 0.95, 0.75, 1.0);
uniform vec4 color_mid : source_color = vec4(1.0, 0.52, 0.12, 1.0);
uniform vec4 color_edge : source_color = vec4(0.75, 0.12, 0.02, 1.0);
uniform float intensity = 3.0;
uniform float speed = 1.5;
instance uniform float seed = 0.0;
uniform float turbulence = 1.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += vnoise(p) * a;
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void vertex() {
	// Keep Y up, face the camera around the Y axis.
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]);
	MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(
		vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
		vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
		vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
		vec4(0.0, 0.0, 0.0, 1.0));
}

void fragment() {
	float y = 1.0 - UV.y;
	float t = TIME * speed + seed * 17.0;
	float n1 = fbm(vec2(UV.x * 3.0, y * 2.5 - t * 1.4));
	float n2 = fbm(vec2(UV.x * 6.0 + 3.1, y * 4.5 - t * 2.3));
	float sway = (n1 - 0.5) * 0.45 * y * turbulence;
	float x = (UV.x - 0.5 - sway) * 2.0;
	float width = mix(0.9, 0.0, pow(clamp(y, 0.0, 1.0), 0.8)) * smoothstep(-0.02, 0.22, y);
	float d = abs(x) / max(width, 0.001);
	float heat = (1.0 - d) * (1.0 - y * 0.55) + (n2 - 0.5) * 0.65 * turbulence;
	heat = clamp(heat, 0.0, 1.0);
	float a = smoothstep(0.02, 0.3, heat);
	vec3 col = mix(color_edge.rgb, color_mid.rgb, smoothstep(0.12, 0.45, heat));
	col = mix(col, color_core.rgb, smoothstep(0.55, 0.92, heat));
	ALBEDO = col * intensity * a;
	ALPHA = a;
}
