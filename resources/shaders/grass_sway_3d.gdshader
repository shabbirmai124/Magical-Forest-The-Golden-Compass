shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// Wind-swaying 3D forest grass & wildflower tufts

uniform sampler2D grass_tex : source_color, filter_linear_mipmap;
uniform float wind_speed = 1.9;
uniform float wind_strength = 0.18;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway_mask = 1.0 - UV.y;
	float phase = v_world_pos.x * 0.6 + v_world_pos.z * 0.45;
	VERTEX.x += sin(TIME * wind_speed + phase) * wind_strength * sway_mask;
	VERTEX.z += cos(TIME * wind_speed * 0.8 + phase * 1.3) * (wind_strength * 0.6) * sway_mask;
}

void fragment() {
	vec4 tex = texture(grass_tex, UV);
	ALPHA = tex.a;
	ALPHA_SCISSOR_THRESHOLD = 0.42;
	ALBEDO = tex.rgb;
	ROUGHNESS = 0.78;
	BACKLIGHT = tex.rgb * 0.42;
	// Subtle bioluminescent tint on wildflower blossoms
	if (tex.b > 0.75 && tex.g > 0.7) {
		EMISSION = tex.rgb * 1.4;
	}
}
