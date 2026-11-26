shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;
// Drifting volumetric-feel 3D woodland mist layer

uniform vec4 mist_color : source_color = vec4(0.32, 0.58, 0.64, 0.22);
uniform float speed = 0.025;

float hash21(vec2 p) {
	p = fract(p * vec2(127.1, 311.7));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float noise2(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash21(i), hash21(i + vec2(1.0, 0.0)), u.x),
		mix(hash21(i + vec2(0.0, 1.0)), hash21(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

void fragment() {
	vec2 p1 = UV * 5.0 + vec2(TIME * speed, TIME * speed * 0.4);
	vec2 p2 = UV * 10.5 - vec2(TIME * speed * 1.3, 0.0);
	float n = noise2(p1) * 0.65 + noise2(p2) * 0.35;
	float edge = smoothstep(0.0, 0.22, UV.x) * smoothstep(1.0, 0.78, UV.x) * smoothstep(0.0, 0.22, UV.y) * smoothstep(1.0, 0.78, UV.y);
	ALBEDO = mist_color.rgb;
	ALPHA = mist_color.a * smoothstep(0.32, 0.82, n) * edge;
}
