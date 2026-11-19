shader_type spatial;
render_mode blend_add, depth_draw_never, cull_back, unshaded;

uniform vec3 aura_color : source_color = vec3(0.2, 0.85, 1.0);
uniform float intensity = 1.0;

void fragment() {
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.4);
	float scan = 0.75 + 0.25 * sin(TIME * 12.0 + FRAGCOORD.y * 0.18);
	ALBEDO = aura_color * (1.4 * intensity);
	ALPHA = clamp(fresnel * 0.85 * scan * intensity, 0.0, 1.0);
}
