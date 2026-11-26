shader_type canvas_item;
// Volumetric diagonal forest light shafts (God rays)

uniform vec4 ray_color : source_color = vec4(0.78, 0.96, 0.82, 0.14);
uniform float angle : hint_range(-1.5, 1.5) = -0.38;
uniform float speed : hint_range(0.0, 2.0) = 0.25;
uniform float ray_density : hint_range(1.0, 20.0) = 7.5;

void fragment() {
	vec2 uv = UV;
	float tilted = uv.x + uv.y * angle;
	float wave1 = sin(tilted * ray_density * 6.28318 + TIME * speed);
	float wave2 = sin(tilted * (ray_density * 1.7) * 6.28318 - TIME * speed * 0.6);
	float beam = smoothstep(0.15, 0.95, (wave1 * 0.6 + wave2 * 0.4) * 0.5 + 0.5);
	float vertical_fade = (1.0 - uv.y) * smoothstep(0.0, 0.15, uv.y);
	float edge_fade = smoothstep(0.0, 0.12, uv.x) * smoothstep(1.0, 0.88, uv.x);
	COLOR = vec4(ray_color.rgb, ray_color.a * beam * vertical_fade * edge_fade);
}
