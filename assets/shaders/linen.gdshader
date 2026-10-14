shader_type spatial;
// Mummy wrappings: diagonal bandage strips with dirt.
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley;

uniform vec4 linen_color : source_color = vec4(0.78, 0.71, 0.56, 1.0);
uniform vec4 dirt_color : source_color = vec4(0.35, 0.27, 0.17, 1.0);
uniform float strip_scale = 14.0;

varying vec3 obj_pos;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

void vertex() {
	obj_pos = VERTEX;
}

void fragment() {
	float diag = obj_pos.y * strip_scale + obj_pos.x * 4.0 + obj_pos.z * 3.0;
	float strip = fract(diag);
	float edge = smoothstep(0.0, 0.12, strip) * (1.0 - smoothstep(0.88, 1.0, strip));
	float id = floor(diag);
	float shade = 0.82 + 0.18 * hash(vec2(id, 3.0));
	float dirt = smoothstep(0.55, 1.0, hash(vec2(floor(obj_pos.x * 12.0), floor(obj_pos.y * 9.0))));
	vec3 col = linen_color.rgb * shade * mix(0.72, 1.0, edge);
	ALBEDO = mix(col, dirt_color.rgb, dirt * 0.45);
	ROUGHNESS = 0.92;
	RIM = 0.4;
	RIM_TINT = 0.3;
}
