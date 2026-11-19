shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D detail_normal : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D noise_tex : repeat_enable, filter_linear_mipmap;

uniform vec2 field_half_size = vec2(29.0, 18.0);
uniform float base_x = 23.0;

uniform vec3 grass_light : source_color = vec3(0.22, 0.48, 0.17);
uniform vec3 grass_dark : source_color = vec3(0.16, 0.39, 0.13);
uniform vec3 outer_grass : source_color = vec3(0.12, 0.29, 0.11);
uniform vec3 dirt_path : source_color = vec3(0.46, 0.38, 0.25);
uniform vec3 chalk_color : source_color = vec3(0.95, 0.94, 0.90);
uniform vec3 blue_paint : source_color = vec3(0.08, 0.44, 0.92);
uniform vec3 blue_paint_dark : source_color = vec3(0.05, 0.28, 0.68);
uniform vec3 red_paint : source_color = vec3(0.88, 0.22, 0.13);
uniform vec3 red_paint_dark : source_color = vec3(0.64, 0.13, 0.08);
uniform vec3 apron_concrete : source_color = vec3(0.56, 0.54, 0.49);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float ring_mask(vec2 p, vec2 c, float r, float w) {
	float d = abs(length(p - c) - r);
	return 1.0 - smoothstep(w * 0.45, w * 0.55, d);
}

float line_mask(float v, float w) {
	return 1.0 - smoothstep(w * 0.45, w * 0.55, abs(v));
}

void fragment() {
	vec2 p = world_pos.xz;
	vec3 n_macro = texture(noise_tex, p * 0.032).rgb;
	vec3 n_micro = texture(noise_tex, p * 0.24).rgb;

	bool in_field = abs(p.x) <= field_half_size.x && abs(p.y) <= field_half_size.y;

	// Alternating pro-mowed 4m turf stripes
	float stripe_idx = floor((p.x + 2.0) / 4.0);
	float stripe_t = mod(stripe_idx, 2.0);

	vec3 turf = mix(grass_dark, grass_light, stripe_t);
	turf *= 0.90 + 0.20 * n_macro.r;
	turf *= 0.92 + 0.15 * n_micro.g;

	// Subtle worn dirt near snake flank alleys
	float flank_wear = smoothstep(13.8, 16.6, abs(p.y)) * smoothstep(22.0, 12.0, abs(p.x));
	float wear_noise = smoothstep(0.42, 0.74, n_macro.g);
	turf = mix(turf, dirt_path * (0.86 + 0.22 * n_micro.r), flank_wear * wear_noise * 0.30);

	// Crisp Pro-Stadium Painted Endzones (clean vibrant Cobalt & Ember diagonal turf stripes — no muddy olive!)
	float in_y_field = 1.0 - smoothstep(field_half_size.y - 0.95, field_half_size.y - 0.75, abs(p.y));
	float in_x_field = 1.0 - smoothstep(field_half_size.x - 0.95, field_half_size.x - 0.75, abs(p.x));
	float ez_diag = step(0.5, fract((p.x + p.y) * 0.24));
	float paint_grain = 0.72 + 0.28 * n_micro.b; // Lets grass texture breathe through the stadium turf paint!

	float blue_ez = smoothstep(-18.6, -18.9, p.x) * in_x_field * in_y_field;
	vec3 blue_ez_col = mix(blue_paint_dark, blue_paint, ez_diag) * (0.90 + 0.14 * n_macro.r);
	turf = mix(turf, mix(turf, blue_ez_col, 0.68 * paint_grain), blue_ez);

	float red_ez = smoothstep(18.6, 18.9, p.x) * in_x_field * in_y_field;
	vec3 red_ez_col = mix(red_paint_dark, red_paint, ez_diag) * (0.90 + 0.14 * n_macro.r);
	turf = mix(turf, mix(turf, red_ez_col, 0.68 * paint_grain), red_ez);

	// Painted midfield tournament circle medallion (crisp split Cobalt / Ember inside center circle)
	float mid_disc = (1.0 - smoothstep(4.65, 4.82, length(p))) * smoothstep(1.35, 1.50, length(p));
	vec3 mid_tint = p.x < 0.0 ? blue_paint : vec3(0.96, 0.26, 0.14);
	turf = mix(turf, mix(turf, mid_tint, 0.50 * paint_grain), mid_disc);

	// Crisp chalk athletic field lines
	float chalk = 0.0;
	if (in_field) {
		float in_z = step(abs(p.y), field_half_size.y - 0.8);
		float bx = line_mask(abs(p.x) - (field_half_size.x - 0.8), 0.22) * step(abs(p.y), field_half_size.y - 0.7);
		float bz = line_mask(abs(p.y) - (field_half_size.y - 0.8), 0.22) * step(abs(p.x), field_half_size.x - 0.7);
		// Endzone goal lines at x = ±18.75m
		float ez_line_l = line_mask(p.x + 18.75, 0.22) * in_z;
		float ez_line_r = line_mask(p.x - 18.75, 0.22) * in_z;
		// Midfield line & center circles
		float mid_line = line_mask(p.x, 0.22) * in_z;
		float mid_ring = ring_mask(p, vec2(0.0, 0.0), 4.8, 0.22);
		float mid_ring_inner = ring_mask(p, vec2(0.0, 0.0), 1.45, 0.18);
		// Base defensive arcs around both pedestals
		float blue_arc = ring_mask(p, vec2(-base_x, 0.0), 4.4, 0.22);
		float red_arc = ring_mask(p, vec2(base_x, 0.0), 4.4, 0.22);
		// Tactical dashed 10m yard lines
		float dash = step(0.42, fract(p.y * 0.35));
		float yard_l = line_mask(p.x + 10.0, 0.14) * dash * in_z;
		float yard_r = line_mask(p.x - 10.0, 0.14) * dash * in_z;

		chalk = max(max(bx, bz), max(ez_line_l, ez_line_r));
		chalk = max(chalk, max(mid_line, max(mid_ring, mid_ring_inner)));
		chalk = max(chalk, max(blue_arc, red_arc));
		chalk = max(chalk, max(yard_l, yard_r) * 0.55);
		chalk *= (0.78 + 0.22 * n_micro.b);
	}

	vec3 col = mix(turf, chalk_color, clamp(chalk, 0.0, 0.94));

	// Concrete walkway apron & deep lush park lawn outside arena perimeter
	float edge_dist = max(abs(p.x) - field_half_size.x, abs(p.y) - field_half_size.y);
	float rough = mix(0.84, 0.72, stripe_t) - chalk * 0.10;
	if (edge_dist > 0.0) {
		float walkway = 1.0 - smoothstep(3.8, 4.3, edge_dist);
		vec3 park = outer_grass * (0.78 + 0.34 * n_macro.r) * (0.90 + 0.18 * n_micro.g);
		vec3 conc = apron_concrete * (0.90 + 0.18 * n_micro.r);
		float joint = 1.0 - (line_mask(fract(p.x * 0.25) - 0.5, 0.025) + line_mask(fract(p.y * 0.25) - 0.5, 0.025)) * 0.18;
		conc *= joint;
		col = mix(park, conc, walkway);
		rough = mix(0.90, 0.76, walkway);
	}

	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.35, 0.95);
	METALLIC = 0.0;
	SPECULAR = 0.28;
	NORMAL_MAP = texture(detail_normal, p * 0.48).rgb;
	NORMAL_MAP_DEPTH = edge_dist > 0.0 && edge_dist < 4.0 ? 0.35 : 0.85;
}
