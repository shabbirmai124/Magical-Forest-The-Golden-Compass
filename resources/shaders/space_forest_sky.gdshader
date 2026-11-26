shader_type sky;
// Expansive 3D Cosmic Night Sky & Moonlit Space Atmosphere for The Lost Golden Compass

uniform vec3 moon_dir = vec3(0.32, 0.42, -0.85);
uniform float star_density : hint_range(20.0, 200.0) = 95.0;

float hash31(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float n000 = hash31(i + vec3(0.0, 0.0, 0.0));
	float n100 = hash31(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash31(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash31(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash31(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash31(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash31(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash31(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
		mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y),
		u.z
	);
}

float fbm3(vec3 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise3(p);
		p *= 2.07;
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	float y = dir.y;

	// Deep cosmic zenith to twilight misty horizon
	vec3 zenith = vec3(0.012, 0.022, 0.068);
	vec3 mid_sky = vec3(0.036, 0.082, 0.175);
	vec3 horizon = vec3(0.085, 0.195, 0.275);
	vec3 abyss = vec3(0.015, 0.028, 0.048);

	vec3 col = mix(horizon, mid_sky, smoothstep(0.0, 0.35, max(y, 0.0)));
	col = mix(col, zenith, smoothstep(0.28, 0.88, max(y, 0.0)));
	if (y < 0.0) {
		col = mix(horizon, abyss, smoothstep(0.0, -0.45, y));
	}

	float sky_mask = smoothstep(-0.04, 0.16, y);

	// Sweeping Milky Way / Cosmic Nebula band across space
	float gal_plane = exp(-pow((dir.y - 0.38 - dir.x * 0.32) * 3.2, 2.0));
	float neb1 = fbm3(dir * 3.8 + vec3(0.0, TIME * 0.004, 0.0));
	float neb2 = fbm3(dir * 7.5 - vec3(TIME * 0.003, 0.0, 0.0));
	vec3 neb_col = mix(vec3(0.06, 0.16, 0.34), vec3(0.18, 0.14, 0.38), neb2);
	col += neb_col * smoothstep(0.36, 0.82, neb1) * gal_plane * 0.62 * sky_mask;

	// Shimmering cosmic aurora curtains high in space
	float aur_wave = sin(dir.x * 5.2 + dir.z * 3.1 + TIME * 0.22 + neb1 * 3.5);
	float aur_band = exp(-pow((dir.y - 0.46 - aur_wave * 0.06) * 7.5, 2.0));
	float aur_rays = smoothstep(0.2, 0.9, 0.5 + 0.5 * sin(dir.x * 26.0 + TIME * 0.45 + neb2 * 4.0));
	col += vec3(0.10, 0.58, 0.54) * aur_band * (0.45 + 0.55 * aur_rays) * 0.36 * sky_mask;

	// Distant faint ringed cosmic planet in deep space
	vec3 pdir = normalize(vec3(-0.48, 0.56, -0.68));
	float p_ang = acos(clamp(dot(dir, pdir), -1.0, 1.0));
	if (p_ang < 0.042) {
		float p_disc = smoothstep(0.022, 0.0205, p_ang);
		vec3 p_up = normalize(cross(pdir, vec3(0.0, 1.0, 0.0)));
		vec3 p_rt = normalize(cross(p_up, pdir));
		vec2 p_uv = vec2(dot(dir, p_rt), dot(dir, p_up));
		float ring_proj = length(vec2(p_uv.x * 0.65 - p_uv.y * 0.35, p_uv.y * 2.6 + p_uv.x * 0.95));
		float ring_band = smoothstep(0.024, 0.026, ring_proj) * smoothstep(0.042, 0.038, ring_proj);
		col = mix(col, vec3(0.24, 0.36, 0.55), ring_band * 0.28 * sky_mask);
		col = mix(col, vec3(0.32, 0.46, 0.66) * (0.65 + 0.35 * smoothstep(-0.02, 0.02, p_uv.x + p_uv.y)), p_disc * 0.52 * sky_mask);
	}

	// Crisp multi-layer 3D starfield
	vec3 star_cell = floor(dir * star_density);
	float s_rnd = hash31(star_cell);
	if (s_rnd > 0.962) {
		vec3 star_center = normalize(star_cell + vec3(0.5) + (vec3(hash31(star_cell + 1.1), hash31(star_cell + 2.3), hash31(star_cell + 3.7)) - 0.5) * 0.6);
		float s_dist = length(dir - star_center) * star_density;
		float twinkle = 0.68 + 0.32 * sin(TIME * (1.8 + s_rnd * 4.0) + s_rnd * 40.0);
		float core = smoothstep(0.28, 0.04, s_dist) * twinkle;
		vec3 s_col = mix(vec3(0.76, 0.88, 1.0), vec3(1.0, 0.94, 0.82), fract(s_rnd * 31.7));
		col += s_col * core * 1.48 * sky_mask;
	}

	// Distant faint fine dust stars
	vec3 fine_cell = floor(dir * (star_density * 2.1));
	float f_rnd = hash31(fine_cell);
	if (f_rnd > 0.975) {
		float f_dist = length(dir - normalize(fine_cell + vec3(0.5))) * (star_density * 2.1);
		col += vec3(0.75, 0.84, 0.98) * smoothstep(0.32, 0.06, f_dist) * 0.55 * sky_mask;
	}

	// Detailed Luminous Full Moon + Rayleigh Halo
	vec3 mdir = normalize(moon_dir);
	float m_dot = dot(dir, mdir);
	float m_ang = acos(clamp(m_dot, -1.0, 1.0));
	float moon_r = 0.068;
	if (m_ang < moon_r * 4.5) {
		float halo = exp(-max(0.0, m_ang - moon_r) * 18.0) * 0.48 + exp(-max(0.0, m_ang - moon_r) * 6.5) * 0.18;
		col += vec3(0.55, 0.78, 1.0) * halo;
		if (m_ang < moon_r) {
			vec3 m_up = normalize(cross(mdir, vec3(0.0, 1.0, 0.0)));
			vec3 m_rt = normalize(cross(m_up, mdir));
			vec2 m_uv = vec2(dot(dir, m_rt), dot(dir, m_up)) / moon_r;
			float r2 = dot(m_uv, m_uv);
			float nz = sqrt(max(0.0, 1.0 - r2));
			float maria = fbm3(vec3(m_uv * 2.8, 1.5));
			float craters = fbm3(vec3(m_uv * 8.5, 4.2));
			float ndotl = clamp(dot(normalize(vec3(m_uv, nz)), normalize(vec3(0.28, 0.22, 0.93))), 0.28, 1.0);
			float disc = smoothstep(moon_r, moon_r * 0.96, m_ang);
			vec3 moon_rgb = vec3(0.92, 0.96, 1.04) * (0.68 + 0.30 * maria + 0.14 * craters) * (0.55 + 0.55 * ndotl);
			col = mix(col, moon_rgb * 1.15, disc);
		}
	}

	// Drifting nocturnal cirrus clouds silver-lit near the moon
	if (y > 0.02) {
		vec2 cloud_uv = dir.xz / (y + 0.22);
		float cl1 = fbm3(vec3(cloud_uv * 0.55 + vec2(TIME * 0.008, TIME * 0.004), 2.1));
		float cl2 = fbm3(vec3(cloud_uv * 1.15 - vec2(TIME * 0.011, 0.0), 5.3));
		float cloud_mask = smoothstep(0.52, 0.82, cl1 * 0.65 + cl2 * 0.35) * smoothstep(0.02, 0.22, y) * smoothstep(0.92, 0.45, y);
		float moon_lit = pow(max(m_dot, 0.0), 5.0);
		vec3 cloud_col = mix(vec3(0.04, 0.08, 0.15), vec3(0.55, 0.76, 0.96), moon_lit * 0.85);
		col = mix(col, cloud_col, cloud_mask * 0.42);
	}

	COLOR = col;
}
