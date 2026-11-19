shader_type spatial;
render_mode blend_add, depth_draw_never, cull_disabled, unshaded;

uniform vec3 ring_color : source_color = vec3(0.1, 0.65, 1.0);
uniform float pulse_speed = 2.0;
uniform float urgency = 0.0; // 0 = calm idle, 1 = carrier approaching to score!

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float ang = atan(p.y, p.x);

	float rot = TIME * (0.7 + urgency * 2.1);
	float seg = 0.55 + 0.45 * sin(ang * 8.0 - rot * 3.0);
	float outer_ring = smoothstep(0.06, 0.0, abs(r - 0.88)) * (0.55 + 0.45 * seg);
	float inner_ring = smoothstep(0.035, 0.0, abs(r - 0.66)) * (0.45 + 0.55 * sin(ang * 4.0 + rot * 2.0));
	float sweep = smoothstep(0.95, 0.2, r) * (0.14 + 0.16 * sin(r * 14.0 - TIME * (3.0 + urgency * 4.0)));

	float pulse = 0.78 + 0.22 * sin(TIME * (pulse_speed + urgency * 5.0));
	float alpha = clamp((outer_ring + inner_ring * 0.75 + sweep * (0.45 + urgency * 0.75)) * pulse, 0.0, 1.0);
	alpha *= smoothstep(1.0, 0.92, r);

	ALBEDO = ring_color * (1.25 + urgency * 0.9);
	ALPHA = alpha * (0.55 + urgency * 0.35);
}
