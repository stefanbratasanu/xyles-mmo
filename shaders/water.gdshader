shader_type spatial;
// Stylised pond water. The mesh covers the carved basin and bakes its exact
// depth into vertex colour, so the gradient and the foam collar come from the
// same analytic bowl that shaped the terrain instead of from a screen-depth
// guess. Ripples perturb the normal directly in world space, which avoids
// tangent generation on the procedural ring mesh.
//
// Colours are deliberately murky: a fen pond reflects a grey-green sky, but the
// body of the water has to stay darker than the bank or it reads as a sheet of
// frosted glass. The foam band is narrow (about one wading step) so the
// shoreline stays crisp without painting a white ring around the whole lake.
render_mode blend_mix, depth_draw_opaque, cull_disabled, specular_schlick_ggx;

uniform vec4 shallow_color : source_color = vec4(0.24, 0.34, 0.27, 0.62);
uniform vec4 deep_color : source_color = vec4(0.035, 0.095, 0.105, 0.94);
uniform vec4 foam_color : source_color = vec4(0.70, 0.78, 0.72, 1.0);
uniform sampler2D ripple_normal : hint_normal, filter_linear_mipmap;
uniform float wave_strength : hint_range(0.0, 1.5) = 0.55;
uniform float wave_speed : hint_range(0.0, 0.15) = 0.020;
uniform float foam_width : hint_range(0.05, 0.8) = 0.22;
uniform float depth_scale : hint_range(0.3, 4.0) = 1.55;

varying float water_depth;
varying vec3 world_pos;

void vertex() {
	// Mesh colour packs depth at half scale so a 1.5 m bowl fits in the 0..1
	// vertex-colour range without clamping at the deepest point.
	water_depth = COLOR.r * 2.0;
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	// A couple of centimetres of swell: enough to catch the light, far too
	// little to lift the mesh out of the bank.
	VERTEX.y += sin(VERTEX.x * 1.3 + TIME * 1.1) * 0.012;
	VERTEX.y += sin(VERTEX.z * 1.7 - TIME * 0.8) * 0.010;
}

void fragment() {
	vec2 uv = world_pos.xz * 0.035;
	vec3 normal_a = texture(ripple_normal, uv + vec2(TIME * wave_speed, TIME * wave_speed * 0.7)).rgb * 2.0 - 1.0;
	vec3 normal_b = texture(ripple_normal, uv * 1.85 - vec2(TIME * wave_speed * 0.6, TIME * wave_speed * 0.35)).rgb * 2.0 - 1.0;
	vec3 bump = (normal_a + normal_b) * 0.5;
	// Tangent-space (x, bitangent, up) -> world (x, up, z).
	vec3 world_normal = normalize(vec3(bump.x * wave_strength, bump.z, bump.y * wave_strength));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	float depth_t = smoothstep(0.0, 1.0, clamp(water_depth / depth_scale, 0.0, 1.0));
	ALBEDO = mix(shallow_color.rgb, deep_color.rgb, depth_t);
	ALPHA = mix(shallow_color.a, deep_color.a, depth_t);

	// Foam exists only in the last few centimetres of depth. The ripple term
	// breaks it into patches instead of a painted outline.
	float foam = 1.0 - smoothstep(0.025, foam_width, water_depth);
	float ripple = 0.60 + 0.40 * sin(world_pos.x * 6.5 + TIME * 1.3) * sin(world_pos.z * 5.5 - TIME * 1.0);
	foam = clamp(foam * ripple, 0.0, 1.0);
	ALBEDO = mix(ALBEDO, foam_color.rgb, foam * 0.80);
	ALPHA = max(ALPHA, foam * 0.72);

	// A restrained fresnel tint; the old value washed the whole pond grey.
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	ALBEDO = mix(ALBEDO, vec3(0.18, 0.26, 0.29), fresnel * 0.18);
	ALPHA = max(ALPHA, fresnel * 0.22);

	// Water is reflective, but a mirror-smooth plane under a bright overcast sky
	// turns into a sheet of grey. The roughness breaks the sky reflection into a
	// soft sheen and lets the depth colour carry the pond.
	ROUGHNESS = 0.30;
	SPECULAR = 0.10;
	METALLIC = 0.0;
}
