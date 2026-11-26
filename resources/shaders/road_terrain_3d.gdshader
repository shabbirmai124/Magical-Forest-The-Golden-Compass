shader_type spatial;
render_mode blend_mix, depth_draw_opaque, cull_back;
// Continuous Road & Woodland Valley Triplanar PBR Blending Shader
// Vertex Color channels:
//   R = Roadbed / Trail mask (packed earth & worn footpath)
//   G = Stone Flagstone / Cobblestone road center & ruin plaza mask
//   B = Bank / Soil / Cliff mask
//   A = Dampness / Moisture sheen (wheel ruts & creek banks)

uniform sampler2D moss_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D moss_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D moss_roughness : filter_linear_mipmap, repeat_enable;

uniform sampler2D soil_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D soil_roughness : filter_linear_mipmap, repeat_enable;

uniform sampler2D stone_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D stone_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D stone_roughness : filter_linear_mipmap, repeat_enable;

uniform float tex_scale = 0.24;
uniform float normal_strength = 0.9;
uniform vec3 road_tint : source_color = vec3(0.86, 0.80, 0.72);
uniform vec3 moss_tint : source_color = vec3(0.84, 0.96, 0.82);

varying vec3 v_world_pos;
varying vec3 v_world_norm;
varying vec4 v_col;

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

vec3 sample_tri_rgb(sampler2D tex, vec3 pos, vec3 blend, float sc) {
	vec3 cx = texture(tex, pos.zy * sc).rgb;
	vec3 cy = texture(tex, pos.xz * sc).rgb;
	vec3 cz = texture(tex, pos.xy * sc).rgb;
	return cx * blend.x + cy * blend.y + cz * blend.z;
}

float sample_tri_r(sampler2D tex, vec3 pos, vec3 blend, float sc) {
	float rx = texture(tex, pos.zy * sc).r;
	float ry = texture(tex, pos.xz * sc).r;
	float rz = texture(tex, pos.xy * sc).r;
	return rx * blend.x + ry * blend.y + rz * blend.z;
}

vec3 sample_tri_wnormal(sampler2D tex_n, vec3 pos, vec3 wn, vec3 blend, float sc) {
	vec3 tx = texture(tex_n, pos.zy * sc).xyz * 2.0 - 1.0;
	vec3 ty = texture(tex_n, pos.xz * sc).xyz * 2.0 - 1.0;
	vec3 tz = texture(tex_n, pos.xy * sc).xyz * 2.0 - 1.0;
	vec3 tnx = vec3(tx.xy * normal_strength + wn.zy, wn.x);
	vec3 tny = vec3(ty.xy * normal_strength + wn.xz, wn.y);
	vec3 tnz = vec3(tz.xy * normal_strength + wn.xy, wn.z);
	return normalize(tnx.zyx * blend.x + tny.xzy * blend.y + tnz.xyz * blend.z);
}

void vertex() {
	v_world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	v_world_norm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	v_col = COLOR;
}

void fragment() {
	vec3 w_n = normalize(v_world_norm);
	vec3 blend = abs(w_n);
	blend = pow(blend, vec3(4.0));
	blend /= max(blend.x + blend.y + blend.z, 0.0001);

	vec3 moss_c = sample_tri_rgb(moss_albedo, v_world_pos, blend, tex_scale) * moss_tint;
	vec3 soil_c = sample_tri_rgb(soil_albedo, v_world_pos, blend, tex_scale * 1.15) * road_tint;
	vec3 stone_c = sample_tri_rgb(stone_albedo, v_world_pos, blend, tex_scale * 1.35);

	float moss_r = sample_tri_r(moss_roughness, v_world_pos, blend, tex_scale);
	float soil_r = sample_tri_r(soil_roughness, v_world_pos, blend, tex_scale * 1.15);
	float stone_r = sample_tri_r(stone_roughness, v_world_pos, blend, tex_scale * 1.35);

	vec3 moss_wn = sample_tri_wnormal(moss_normal, v_world_pos, w_n, blend, tex_scale);
	vec3 soil_wn = sample_tri_wnormal(soil_normal, v_world_pos, w_n, blend, tex_scale * 1.15);
	vec3 stone_wn = sample_tri_wnormal(stone_normal, v_world_pos, w_n, blend, tex_scale * 1.35);

	float macro = vnoise(v_world_pos.xz * 0.09) * 0.55 + vnoise(v_world_pos.xz * 0.31) * 0.45;
	float micro = vnoise(v_world_pos.xz * 1.4);

	float steep_soil = smoothstep(0.88, 0.62, w_n.y);
	float bank_w = clamp(max(v_col.b, steep_soil * 0.85), 0.0, 1.0);
	float road_w = clamp(v_col.r + (macro - 0.5) * 0.14 * v_col.r, 0.0, 1.0);
	float cobble_w = clamp(v_col.g * smoothstep(0.32, 0.72, micro + macro * 0.35), 0.0, 1.0);
	float damp_w = clamp(v_col.a * (0.7 + 0.3 * macro), 0.0, 1.0);

	// Blend grass/moss -> forest bank soil -> packed earth road -> ancient cobblestones
	vec3 col = mix(moss_c, soil_c * 0.88, bank_w);
	vec3 wn = normalize(mix(moss_wn, soil_wn, bank_w));
	float rough = mix(moss_r, soil_r, bank_w);

	col = mix(col, soil_c, road_w);
	wn = normalize(mix(wn, soil_wn, road_w));
	rough = mix(rough, soil_r * 0.92, road_w);

	col = mix(col, stone_c, cobble_w);
	wn = normalize(mix(wn, stone_wn, cobble_w));
	rough = mix(rough, stone_r * 0.88, cobble_w);

	// Subtle macro tonal variation & moisture darkening in tracks / stream banks
	col *= mix(0.82, 1.14, macro);
	col *= mix(1.0, 0.68, damp_w * 0.55);
	rough = mix(rough, 0.24, damp_w * 0.62);

	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);
	ALBEDO = col;
	ROUGHNESS = clamp(rough, 0.22, 0.96);
	SPECULAR = mix(0.45, 0.78, damp_w);
	AO = mix(0.62, 1.0, smoothstep(-0.25, 0.7, w_n.y)) * mix(0.86, 1.0, macro);
}
