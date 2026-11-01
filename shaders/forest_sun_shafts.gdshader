shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// Crossed, depth-tested cards approximate light scattered in a narrow column.
// Each instance supplies a different width, length and opacity.
uniform vec2 sun_slope = vec2(0.0);
uniform float daylight : hint_range(0.0, 1.0) = 1.0;
uniform bool enabled = true;
varying float ray_strength;

void vertex() {
	float width = INSTANCE_CUSTOM.r * 4.0;
	float height = INSTANCE_CUSTOM.g * 12.0;
	VERTEX.xz *= width;
	VERTEX.xz += sun_slope * VERTEX.y * height;
	VERTEX.y *= height;
	ray_strength = INSTANCE_CUSTOM.b;
}

void fragment() {
	float centre = max(0.0, 1.0 - abs(UV.x * 2.0 - 1.0));
	float edge = pow(centre, 1.7);
	float ends = smoothstep(0.0, 0.18, UV.y) * (1.0 - smoothstep(0.70, 1.0, UV.y));
	ALBEDO = vec3(0.90, 0.79, 0.57);
	ALPHA = edge * ends * ray_strength * daylight * 0.22 * float(enabled);
}
