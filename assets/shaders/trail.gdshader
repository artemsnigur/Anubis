shader_type spatial;
// Weapon trail ribbon. UV.x = age along the trail (0 = newest), UV.y = base(0) -> tip(1).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 core_color : source_color = vec4(1.0, 0.95, 0.75, 1.0);
uniform vec4 edge_color : source_color = vec4(0.25, 0.85, 0.85, 1.0);
uniform float intensity = 1.6;

void fragment() {
	float age = UV.x;
	float across = UV.y;
	float fade = pow(1.0 - age, 1.6) * COLOR.a;
	float tip = smoothstep(0.0, 0.85, across);
	vec3 col = mix(edge_color.rgb, core_color.rgb, tip * (1.0 - age));
	float a = fade * smoothstep(0.0, 0.25, across) * (0.35 + 0.65 * tip);
	ALBEDO = col * intensity * a;
	ALPHA = a;
}
