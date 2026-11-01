shader_type sky;

// Frontier sky: a moving cloud deck over the authored day/night gradient.
// Colours are driven from world_builder.gd, so the sky, fog and sun always agree.
//
// The clouds sample 3D value noise on the view direction. An earlier version
// projected the ray onto a flat plane, which is singular at the zenith: every
// noise cell edge fanned out into long triangular shards above the player. The
// spherical mapping has no pole, so the deck wraps evenly in every direction.

uniform vec3 top_color : source_color = vec3(0.235, 0.435, 0.596);
uniform vec3 horizon_color : source_color = vec3(0.765, 0.788, 0.675);
uniform vec3 ground_horizon_color : source_color = vec3(0.561, 0.608, 0.514);
uniform vec3 ground_bottom_color : source_color = vec3(0.141, 0.204, 0.173);
uniform vec3 cloud_color : source_color = vec3(0.94, 0.93, 0.88);
uniform vec3 cloud_shadow : source_color = vec3(0.55, 0.58, 0.64);
uniform vec3 sun_tint : source_color = vec3(1.0, 0.72, 0.45);
uniform vec3 star_color : source_color = vec3(0.82, 0.88, 1.0);
uniform float coverage : hint_range(0.0, 1.0) = 0.46;
uniform float cloud_opacity : hint_range(0.0, 1.0) = 0.92;
uniform float wind_speed = 0.010;
uniform float night_amount : hint_range(0.0, 1.0) = 0.0;
uniform float sun_glow : hint_range(0.0, 1.5) = 1.0;
uniform vec3 mist_color : source_color = vec3(0.54, 0.61, 0.55);

float hash3(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yzx + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	float n000 = hash3(i);
	float n100 = hash3(i + vec3(1.0, 0.0, 0.0));
	float n010 = hash3(i + vec3(0.0, 1.0, 0.0));
	float n110 = hash3(i + vec3(1.0, 1.0, 0.0));
	float n001 = hash3(i + vec3(0.0, 0.0, 1.0));
	float n101 = hash3(i + vec3(1.0, 0.0, 1.0));
	float n011 = hash3(i + vec3(0.0, 1.0, 1.0));
	float n111 = hash3(i + vec3(1.0, 1.0, 1.0));
	return mix(
		mix(mix(n000, n100, u.x), mix(n010, n110, u.x), u.y),
		mix(mix(n001, n101, u.x), mix(n011, n111, u.x), u.y),
		u.z);
}

float fbm3(vec3 p) {
	float sum = 0.0;
	float amp = 0.55;
	for (int i = 0; i < 5; i++) {
		sum += amp * value_noise3(p);
		p = p * 2.03 + vec3(11.7, 5.3, 9.1);
		amp *= 0.5;
	}
	return sum / 1.06;
}

void sky() {
	float up = clamp(EYEDIR.y, 0.0, 1.0);
	vec3 col = mix(horizon_color, top_color, pow(up, 0.55));
	if (EYEDIR.y < 0.0) {
		float down = clamp(-EYEDIR.y, 0.0, 1.0);
		col = mix(ground_horizon_color, ground_bottom_color, pow(down, 0.60));
	}

	float sun_dot = max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0);
	col += sun_tint * pow(sun_dot, 128.0) * 1.35 * sun_glow;
	col += sun_tint * pow(sun_dot, 8.0) * 0.14 * sun_glow;

	vec3 dir = normalize(EYEDIR);
	if (dir.y > 0.004) {
		// Two noise layers drift at different speeds for parallax. Sampling the
		// direction itself keeps cloud shape stable while the deck crosses the sky.
		vec3 wind = vec3(TIME * wind_speed, 0.0, TIME * wind_speed * 0.34);
		float base = fbm3(dir * 3.6 + wind * 1.7);
		float billow = fbm3(dir * 9.2 - wind * 2.3 + vec3(5.2, 1.3, 7.1));
		float noise_value = base * 0.68 + billow * 0.32;
		float threshold = mix(0.62, 0.40, clamp(coverage, 0.0, 1.0));
		float mask = smoothstep(threshold, threshold + 0.16, noise_value);
		// Clouds dissolve into the haze at the horizon instead of ending in a
		// hard band, and thin out directly around the sun.
		float horizon_fade = smoothstep(0.004, 0.16, dir.y);
		float sun_thin = 1.0 - pow(sun_dot, 5.0) * 0.45;
		mask *= horizon_fade * sun_thin * (1.0 - night_amount);
		vec3 lit = mix(cloud_shadow, cloud_color, smoothstep(0.38, 0.78, noise_value));
		lit += sun_tint * pow(sun_dot, 4.0) * 0.18 * sun_glow;
		lit = mix(lit, lit * 0.24, night_amount * 0.72);
		col = mix(col, lit, mask * cloud_opacity);
	}

	// Sparse stars appear with the same night factor that dims the clouds.
	if (night_amount > 0.02 && dir.y > 0.03) {
		vec3 cell = floor(dir * 340.0);
		float star = step(0.9976, hash3(cell));
		float twinkle = 0.65 + 0.35 * hash3(cell + floor(vec3(TIME * 2.0)));
		col += star_color * star * twinkle * (1.0 - smoothstep(0.05, 0.35, dir.y) * 0.4) * night_amount;
	}

	// The sky has no distant geometry to receive scene fog. Blend a soft
	// horizon band into the same day/night color so bare streaming horizons do
	// not end abruptly in blue sky. Keep the upper clouds and stars visible.
	float horizon_mist = 1.0 - smoothstep(0.0, 0.11, abs(dir.y));
	col = mix(col, mist_color, horizon_mist * 0.65);
	COLOR = col;
}
