shader_type canvas_item;
// Smooth peripheral screen vignette for hit feedback & low vitality warning

uniform vec4 vignette_color : source_color = vec4(0.75, 0.06, 0.08, 1.0);
uniform float intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec2 centered = UV - vec2(0.5);
	float dist = length(centered * vec2(1.15, 1.0)) * 1.414;
	float vig = smoothstep(0.42, 1.05, dist);
	COLOR = vec4(vignette_color.rgb, vig * intensity * 0.72);
}
