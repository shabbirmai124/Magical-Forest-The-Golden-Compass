shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;
// Animated swirling arcane dimensional portal shader for LevelExit3D

uniform vec3 outer_color : source_color = vec3(0.06, 0.62, 0.72);
uniform vec3 inner_color : source_color = vec3(0.68, 1.0, 0.96);

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float r = length(uv);
	float ang = atan(uv.y, uv.x);
	float swirl = sin(ang * 4.0 - r * 12.0 + TIME * 4.2) * 0.5 + 0.5;
	float ripple = sin(r * 18.0 - TIME * 5.0) * 0.5 + 0.5;
	float core = smoothstep(1.0, 0.15, r);
	vec3 col = mix(outer_color, inner_color, clamp(core * 0.6 + swirl * 0.35 + ripple * 0.2, 0.0, 1.0));
	float alpha = smoothstep(1.02, 0.78, r) * (0.72 + 0.25 * swirl);
	ALBEDO = col * 1.35;
	ALPHA = alpha;
}
