shader_type spatial;
// Overlay used for hit flashes / telegraph tints. Applied as material_overlay only while flashing.
render_mode unshaded, blend_add, depth_draw_never, cull_back;

uniform vec4 flash_color : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float amount = 0.0;

void fragment() {
	ALBEDO = flash_color.rgb * amount;
	ALPHA = amount;
}
