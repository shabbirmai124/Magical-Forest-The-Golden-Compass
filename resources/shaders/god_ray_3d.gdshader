shader_type spatial;
render_mode unshaded, cull_disabled, blend_add, depth_draw_never;
// Soft Volumetric Canopy Moonlight God-Ray Shafts

uniform vec4 ray_color : source_color = vec4(0.42, 0.72, 0.96, 0.085);

void fragment() {
	float v_fade = smoothstep(0.0, 0.28, UV.y) * smoothstep(1.0, 0.18, UV.y);
	float edge_fade = pow(abs(dot(normalize(NORMAL), normalize(VIEW))), 1.6);
	float shimmer = 0.82 + 0.18 * sin(UV.x * 18.0 + TIME * 0.75);
	float alpha = ray_color.a * v_fade * edge_fade * shimmer;
	ALBEDO = ray_color.rgb;
	ALPHA = alpha;
}
