shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;
// Botanical Woodland Canopy & Fern Wind Sway Shader with Moonlight Subsurface Backlight

uniform sampler2D foliage_tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform float wind_speed = 1.65;
uniform float wind_strength = 0.14;
uniform float emissive_spores = 1.35;

varying vec3 v_world_pos;

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway_w = clamp(1.0 - UV.y * 0.85, 0.1, 1.0);
	float ph = v_world_pos.x * 0.42 + v_world_pos.z * 0.38 + v_world_pos.y * 0.25;
	VERTEX.x += (sin(TIME * wind_speed + ph) * 0.7 + sin(TIME * wind_speed * 2.3 + ph * 1.9) * 0.3) * wind_strength * sway_w;
	VERTEX.z += (cos(TIME * wind_speed * 0.85 + ph * 1.2) * 0.7) * wind_strength * sway_w;
}

void fragment() {
	vec4 tex = texture(foliage_tex, UV);
	ALPHA = tex.a * tint.a;
	ALPHA_SCISSOR_THRESHOLD = 0.44;
	ALBEDO = tex.rgb * tint.rgb;
	ROUGHNESS = 0.74;
	SPECULAR = 0.32;
	// Subsurface scatter under moonlight & warm lantern light
	BACKLIGHT = tex.rgb * 0.48;
	if (tex.b > 0.76 && tex.g > 0.78) {
		EMISSION = tex.rgb * emissive_spores;
	}
}
