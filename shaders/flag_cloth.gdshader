shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_disabled, diffuse_burley, specular_schlick_ggx;

uniform sampler2D flag_albedo : source_color, filter_linear_mipmap;
uniform float wind_speed = 5.2;
uniform float wind_strength = 0.22;
uniform float runner_speed = 0.0;
uniform vec3 backlight_tint : source_color = vec3(0.55, 0.70, 1.0);

void vertex() {
	// UV.x = 0 at flagpole hoist, 1 at fly tip
	float u = clamp(UV.x, 0.0, 1.0);
	float pin = smoothstep(0.0, 0.14, u);
	float speed_boost = 1.0 + runner_speed * 0.22;
	float t = TIME * wind_speed * speed_boost;

	float w1 = sin(u * 6.8 - t) * 0.72;
	float w2 = sin(u * 13.5 - t * 1.45 + UV.y * 2.4) * 0.28;
	float wave = (w1 + w2) * wind_strength * (0.45 + 0.55 * clamp(speed_boost * 0.65, 0.5, 1.6)) * pin * (0.35 + 0.65 * u);

	VERTEX.x += wave;
	VERTEX.y += sin(u * 5.0 - t * 0.9) * 0.045 * pin * u;

	// Analytical partial derivative for realistic sunlit cloth folds
	float dw_du = (cos(u * 6.8 - t) * 6.8 * 0.72 + cos(u * 13.5 - t * 1.45 + UV.y * 2.4) * 13.5 * 0.28) * wind_strength * 0.18 * pin;
	NORMAL = normalize(NORMAL + vec3(0.0, 0.0, -dw_du));
}

void fragment() {
	vec4 tex = texture(flag_albedo, UV);
	ALBEDO = tex.rgb;
	ROUGHNESS = 0.42;
	METALLIC = 0.02;
	SPECULAR = 0.45;
	// Subtle sunlit backlit cloth translucency
	BACKLIGHT = tex.rgb * backlight_tint * 0.45;
}
