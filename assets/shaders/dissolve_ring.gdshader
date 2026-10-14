shader_type spatial;
// Unshaded additive ring / disc used for shockwaves and ground telegraphs.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;

uniform vec4 color : source_color = vec4(1.0, 0.6, 0.2, 1.0);
uniform float intensity = 2.0;
uniform float fill = 0.0;       // 0..1 progress (ground telegraph fill)
uniform float thickness = 0.12; // ring thickness in UV radius units
uniform float alpha = 1.0;
uniform bool show_fill = false;

void fragment() {
	vec2 c = UV * 2.0 - 1.0;
	float r = length(c);
	if (r > 1.0) {
		discard;
	}
	float ring = smoothstep(1.0 - thickness, 1.0 - thickness * 0.5, r) * (1.0 - smoothstep(0.97, 1.0, r));
	float inner = 0.0;
	if (show_fill) {
		inner = (1.0 - smoothstep(fill - 0.04, fill, r)) * 0.35 + smoothstep(fill - 0.06, fill, r) * (1.0 - smoothstep(fill, fill + 0.02, r)) * 0.8;
	}
	float a = clamp(ring + inner, 0.0, 1.0) * alpha;
	ALBEDO = color.rgb * intensity * a;
	ALPHA = a;
}
