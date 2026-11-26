shader_type canvas_item;
// Subtle drifting ground mist / woodland fog

uniform vec4 mist_color : source_color = vec4(0.45, 0.72, 0.68, 0.16);
uniform float drift_speed : hint_range(-1.0, 1.0) = 0.04;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
		u.y
	);
}

void fragment() {
	vec2 p = vec2(UV.x * 5.0 + TIME * drift_speed, UV.y * 2.5);
	float n = noise(p) * 0.65 + noise(p * 2.2 - vec2(TIME * drift_speed * 1.4, 0.0)) * 0.35;
	float fade_y = smoothstep(0.0, 0.4, UV.y) * smoothstep(1.0, 0.7, UV.y);
	COLOR = vec4(mist_color.rgb, mist_color.a * smoothstep(0.35, 0.85, n) * fade_y);
}
