shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// Flowing Traveler Cloth Cloak Shader driven by movement speed & wind turbulence

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec4 cloak_tint : source_color = vec4(0.92, 1.0, 0.96, 1.0);
uniform float move_speed_norm = 0.0;

void vertex() {
	float hem = clamp(UV.y, 0.0, 1.0);
	float flutter_freq = 3.2 + move_speed_norm * 7.5;
	float flutter_amp = 0.028 + move_speed_norm * 0.095;
	float w1 = sin(TIME * flutter_freq + VERTEX.x * 5.5 - VERTEX.y * 4.2);
	float w2 = cos(TIME * (flutter_freq * 1.45) + VERTEX.x * 8.0);
	VERTEX.z += (w1 * 0.7 + w2 * 0.3) * flutter_amp * hem * hem + move_speed_norm * 0.22 * (hem * hem);
	VERTEX.x += sin(TIME * 2.4 + VERTEX.y * 3.0) * 0.015 * hem;
}

void fragment() {
	vec2 uvv = UV * vec2(1.8, 2.4);
	ALBEDO = texture(albedo_tex, uvv).rgb * cloak_tint.rgb;
	NORMAL_MAP = texture(normal_tex, uvv).rgb;
	NORMAL_MAP_DEPTH = 0.85;
	ROUGHNESS = 0.86;
	RIM = 0.42;
	RIM_TINT = 0.28;
	BACKLIGHT = vec3(0.16, 0.26, 0.2);
}
