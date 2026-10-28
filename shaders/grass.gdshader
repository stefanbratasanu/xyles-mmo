shader_type spatial;

// Grass tufts: alpha-to-coverage instead of alpha scissor so 4x MSAA smooths
// every blade edge, plus a cheap world-space wind bend. The mesh is a MultiMesh;
// MODEL_MATRIX carries each instance transform, so the phase differs per tuft
// and whole meadows move in slow waves rather than in lockstep.

render_mode cull_disabled, alpha_to_coverage, diffuse_lambert_wrap;

uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec3 albedo_tint : source_color = vec3(1.0);
uniform float wind_strength : hint_range(0.0, 0.30) = 0.045;
uniform float wind_speed : hint_range(0.0, 4.0) = 1.35;

void vertex() {
	vec3 origin = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	// UV.y is 1 at the root and 0 at the blade tip in the tuft mesh.
	float bend = 1.0 - clamp(UV.y, 0.0, 1.0);
	bend *= bend;
	// Horizontal rosette cards must not flap like vertical blades.
	bend *= 1.0 - abs(NORMAL.y) * 0.62;
	float phase = origin.x * 0.23 + origin.z * 0.17;
	float gust = sin(TIME * wind_speed + phase) + 0.35 * sin(TIME * wind_speed * 2.7 + phase * 1.9);
	VERTEX.x += gust * wind_strength * bend;
	VERTEX.z += cos(TIME * wind_speed * 0.72 + phase * 1.3) * wind_strength * 0.55 * bend;
}

void fragment() {
	vec4 tex = texture(grass_texture, UV);
	ALBEDO = tex.rgb * COLOR.rgb * albedo_tint;
	ALPHA = tex.a;
	ROUGHNESS = 0.95;
	SPECULAR = 0.12;
	BACKLIGHT = vec3(0.33, 0.40, 0.19);
}
