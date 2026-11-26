shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
// Full PBR Triplanar Terrain Blending with UDN World-Space Normals & Crevice Moss (WebGL2 safe: 4 samplers)

uniform sampler2D top_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D top_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D side_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D side_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform float tex_scale = 0.22;
uniform float moss_threshold = 0.54;
uniform float normal_strength = 0.85;

varying vec3 v_world_pos;
varying vec3 v_world_norm;

float hash21(vec2 p) {
	p = fract(p * vec2(234.34, 435.345));
	p += dot(p, p + 34.23);
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

vec3 sample_tri_rgb(sampler2D tex, vec3 pos, vec3 blend) {
	vec3 cx = texture(tex, pos.zy * tex_scale).rgb;
	vec3 cy = texture(tex, pos.xz * tex_scale).rgb;
	vec3 cz = texture(tex, pos.xy * tex_scale).rgb;
	return cx * blend.x + cy * blend.y + cz * blend.z;
}

vec3 sample_tri_wnormal(sampler2D tex_n, vec3 pos, vec3 wn, vec3 blend) {
	vec3 tx = texture(tex_n, pos.zy * tex_scale).xyz * 2.0 - 1.0;
	vec3 ty = texture(tex_n, pos.xz * tex_scale).xyz * 2.0 - 1.0;
	vec3 tz = texture(tex_n, pos.xy * tex_scale).xyz * 2.0 - 1.0;
	vec3 tnx = vec3(tx.xy * normal_strength + wn.zy, wn.x);
	vec3 tny = vec3(ty.xy * normal_strength + wn.xz, wn.y);
	vec3 tnz = vec3(tz.xy * normal_strength + wn.xy, wn.z);
	return normalize(tnx.zyx * blend.x + tny.xzy * blend.y + tnz.xyz * blend.z);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_norm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 w_n = normalize(v_world_norm);
	vec3 blend = abs(w_n);
	blend = pow(blend, vec3(4.0));
	blend /= max(blend.x + blend.y + blend.z, 0.0001);

	vec3 top_col = sample_tri_rgb(top_albedo, v_world_pos, blend);
	vec3 side_col = sample_tri_rgb(side_albedo, v_world_pos, blend);
	vec3 top_wn = sample_tri_wnormal(top_normal, v_world_pos, w_n, blend);
	vec3 side_wn = sample_tri_wnormal(side_normal, v_world_pos, w_n, blend);

	// Macro breakup + rock crevice height modulation so moss clings inside cliff cracks
	float macro = vnoise(v_world_pos.xz * 0.12) * 0.6 + vnoise(v_world_pos.xz * 0.37) * 0.4;
	float side_luma = dot(side_col, vec3(0.3, 0.59, 0.11));
	float top_luma = dot(top_col, vec3(0.3, 0.59, 0.11));
	float crevice = (0.35 - side_luma) * 0.45;
	float slope_mask = smoothstep(moss_threshold - 0.16, moss_threshold + 0.16, w_n.y + (macro - 0.5) * 0.28 + crevice);

	vec3 col = mix(side_col, top_col, slope_mask);
	col *= mix(0.78, 1.18, macro);

	vec3 final_wn = normalize(mix(side_wn, top_wn, slope_mask));
	NORMAL = normalize((VIEW_MATRIX * vec4(final_wn, 0.0)).xyz);

	float top_r = clamp(0.88 - top_luma * 0.2, 0.58, 0.94);
	float side_r = clamp(0.84 - side_luma * 0.28, 0.44, 0.92);

	ALBEDO = col;
	ROUGHNESS = clamp(mix(side_r, top_r, slope_mask), 0.35, 0.96);
	SPECULAR = 0.52;
	AO = mix(0.55, 1.0, smoothstep(-0.35, 0.65, w_n.y)) * mix(0.84, 1.0, side_luma);
}
