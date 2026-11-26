shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
// Luminous Celestial Cloudbank Shader for High-Altitude Sky-Road (Stage 4)

uniform vec4 cloud_lit_color : source_color = vec4(0.84, 0.90, 1.0, 0.94);
uniform vec4 cloud_shadow_color : source_color = vec4(0.14, 0.21, 0.38, 0.90);
uniform vec4 rim_glow_color : source_color = vec4(0.55, 0.88, 1.0, 1.0);
uniform float drift_speed = 0.28;

varying vec3 v_world_pos;
varying vec3 v_world_norm;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 34.5);
	return fract(p.x * p.y);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

void vertex() {
	vec3 wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float wave = sin(TIME * drift_speed + wp.x * 0.08 + wp.z * 0.06) * 0.35;
	float puff = cos(TIME * drift_speed * 1.4 - wp.x * 0.12 + wp.z * 0.1) * 0.22;
	VERTEX.y += (wave + puff) * clamp(NORMAL.y * 0.5 + 0.5, 0.0, 1.0);
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_norm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 wn = normalize(v_world_norm);
	vec2 p = v_world_pos.xz * 0.055 + vec2(TIME * 0.025, TIME * 0.015);
	float n = vnoise(p) * 0.62 + vnoise(p * 2.4 + 3.1) * 0.38;

	float top_lit = smoothstep(-0.3, 0.85, wn.y + (n - 0.5) * 0.45);
	vec3 base_col = mix(cloud_shadow_color.rgb, cloud_lit_color.rgb, top_lit);
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), VIEW), 0.0, 1.0), 2.4);

	ALBEDO = base_col;
	EMISSION = rim_glow_color.rgb * fresnel * (0.28 + 0.32 * top_lit);
	ROUGHNESS = 0.92;
	SPECULAR = 0.18;
	BACKLIGHT = cloud_lit_color.rgb * 0.55;
	ALPHA = clamp(mix(0.76, 0.97, top_lit) * smoothstep(-0.7, 0.15, wn.y), 0.25, 0.96);
}
