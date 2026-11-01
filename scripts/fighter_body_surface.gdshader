shader_type spatial;
uniform sampler2D skin_texture : source_color, filter_linear_mipmap;
uniform float softness : hint_range(0.0, 1.0) = 0.0;
uniform vec3 common_tone = vec3(0.509, 0.309, 0.188);
uniform float neck_center = 1.585;
uniform float neck_width = 0.048;
uniform vec3 skin_warmth = vec3(1.0, 0.90, 0.82);
uniform float stubble : hint_range(0.0, 1.0) = 0.50;
uniform bool coverage_enabled = false;
uniform bool outfit_visible = true;
varying float torso_mask;
varying float neck_mask;
varying float beard_mask;
varying float covered_skin;

void vertex() {
	covered_skin = COLOR.a;
	torso_mask = smoothstep(1.0, 1.12, VERTEX.y)
		* (1.0 - smoothstep(1.45, 1.56, VERTEX.y))
		* (1.0 - smoothstep(0.15, 0.29, abs(VERTEX.x)));
	// The head and body textures meet at the welded neck ring. Blending both
	// surfaces to one shared neck colour removes the material boundary without
	// depending on an exported vertex-colour channel.
	neck_mask = 1.0 - smoothstep(0.0, neck_width, abs(VERTEX.y - neck_center));
	// A faint shaved-shadow along the jaw and chin: the generated source has no
	// facial hair and reads as a smooth mannequin head without it.
	float front = smoothstep(0.01, 0.055, VERTEX.z);
	float chin = smoothstep(1.615, 1.635, VERTEX.y) * (1.0 - smoothstep(1.715, 1.745, VERTEX.y));
	float jaw = 1.0 - smoothstep(0.060, 0.080, abs(VERTEX.x));
	beard_mask = front * chin * jaw;
}

void fragment() {
	if (coverage_enabled && outfit_visible && covered_skin > 0.5) {
		discard;
	}
	vec3 detailed = texture(skin_texture, UV).rgb;
	// Average nearby samples instead of reducing the entire atlas to 32px.
	// This softens baked muscle shadows without coarse mip-level patches.
	vec3 broad = vec3(0.0);
	for (int x = -1; x <= 1; x++) {
		for (int y = -1; y <= 1; y++) {
			broad += textureLod(skin_texture, UV + vec2(float(x), float(y)) * 0.008, 5.0).rgb;
		}
	}
	broad /= 9.0;
	// The source atlas has painted abdominal shadows. Blurring those alone
	// leaves a six-pack on a low-muscle body. Replace that low-frequency
	// contrast with the sampled skin tone while retaining fine surface detail.
	broad = mix(broad, common_tone, 0.85) + (detailed - textureLod(skin_texture, UV, 2.0).rgb) * 0.25;
	vec3 skin = mix(detailed, broad, softness * torso_mask * 0.9);
	skin *= skin_warmth;
	vec3 stubble_color = skin * vec3(0.50, 0.44, 0.40);
	skin = mix(skin, stubble_color, beard_mask * stubble);
	ALBEDO = mix(skin, common_tone * skin_warmth, neck_mask);
	ROUGHNESS = 0.82;
	SPECULAR = 0.25;
}



