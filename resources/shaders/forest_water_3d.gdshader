shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
// Moonlit Woodland Lake & Shimmering Aurora Reflection Water Shader

uniform sampler2D water_normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 deep_color : source_color = vec4(0.014, 0.036, 0.072, 0.94);
uniform vec4 shallow_color : source_color = vec4(0.045, 0.145, 0.195, 0.88);
uniform vec3 moon_dir = vec3(0.32, 0.42, -0.85);

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += sin(v_world_pos.x * 0.45 + TIME * 1.1) * 0.045 + cos(v_world_pos.z * 0.38 - TIME * 0.9) * 0.04;
}

void fragment() {
	vec2 uv1 = v_world_pos.xz * 0.055 + vec2(TIME * 0.018, TIME * 0.011);
	vec2 uv2 = v_world_pos.xz * 0.095 - vec2(TIME * 0.014, -TIME * 0.016);
	vec3 n1 = texture(water_normal_tex, uv1).xyz * 2.0 - 1.0;
	vec3 n2 = texture(water_normal_tex, uv2).xyz * 2.0 - 1.0;
	vec3 n_tan = normalize(vec3((n1.xy + n2.xy) * 0.42, 1.0));
	vec3 wn = normalize(vec3(n_tan.x, 1.0, n_tan.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);

	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	vec3 world_view = normalize((INV_VIEW_MATRIX * vec4(VIEW, 0.0)).xyz);
	vec3 refl_world = reflect(-world_view, wn);
	vec3 moon_glint_col = vec3(0.75, 0.9, 1.0) * pow(max(dot(normalize(refl_world), normalize(moon_dir)), 0.0), 96.0) * 2.6;
	vec3 aurora_refl = mix(vec3(0.06, 0.18, 0.28), vec3(0.12, 0.44, 0.46), 0.5 + 0.5 * sin(v_world_pos.x * 0.06 + TIME * 0.35));

	ALBEDO = mix(deep_color.rgb, mix(shallow_color.rgb, aurora_refl, 0.65), fresnel);
	EMISSION = moon_glint_col + aurora_refl * fresnel * 0.22;
	ROUGHNESS = 0.09;
	SPECULAR = 0.88;
	METALLIC = 0.12;
	ALPHA = mix(0.86, 0.97, fresnel);
}
