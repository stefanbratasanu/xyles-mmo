extends RefCounted
## Small 3D LUTs applied by the world Environment after tonemapping.
const PRESETS := {
	"neutral": {"name":"Original", "description":"Current game colors."},
	"purple": {"name":"Purple dusk", "description":"Cool violet shadows and a subtle violet cast.", "tint":Vector3(.045, -.015, .08), "contrast":1.04, "saturation":.96},
	"red": {"name":"Crimson", "description":"Warmer red-brown shadows and highlights.", "tint":Vector3(.08, -.025, -.025), "contrast":1.04, "saturation":.96},
	"orange": {"name":"Golden amber", "description":"Warm golden light and earthy shadows.", "tint":Vector3(.085, .025, -.055), "contrast":1.04, "saturation":1.02},
	"cool": {"name":"Cool forest", "description":"Cool blue-green shadows with clear highlights.", "tint":Vector3(-.035, .015, .065), "contrast":1.06, "saturation":.95},
	"dark": {"name":"Dark cinematic", "description":"Darker, less saturated colors and deeper contrast.", "tint":Vector3(.005, -.005, .02), "contrast":1.13, "saturation":.80, "brightness":.91},
}
const SIZE := 17
var cache: Dictionary = {}

func apply(environment: Environment, id: String) -> bool:
	if environment == null or not PRESETS.has(id): return false
	if id == "neutral":
		environment.adjustment_enabled = false
		environment.adjustment_color_correction = null
		environment.adjustment_brightness = 1.0
		environment.adjustment_contrast = 1.0
		environment.adjustment_saturation = 1.0
		return true
	if not cache.has(id): cache[id] = _make_lut(PRESETS[id].tint)
	if cache[id] == null: return false
	var preset: Dictionary = PRESETS[id]
	environment.adjustment_color_correction = cache[id]
	environment.adjustment_brightness = preset.get("brightness", 1.0)
	environment.adjustment_contrast = preset.get("contrast", 1.0)
	environment.adjustment_saturation = preset.get("saturation", 1.0)
	environment.adjustment_enabled = true
	return true

func _make_lut(tint: Vector3) -> ImageTexture3D:
	var slices: Array[Image] = []
	for z in range(SIZE):
		var image := Image.create(SIZE, SIZE, false, Image.FORMAT_RGB8)
		for y in range(SIZE):
			for x in range(SIZE):
				var c := Vector3(float(x), float(y), float(z)) / float(SIZE - 1)
				# Split-toned shadows and restrained highlights retain neutral blacks.
				var luminosity := c.dot(Vector3(.2126, .7152, .0722))
				var influence := smoothstep(0.0, .18, luminosity) * (1.0 - .35 * luminosity)
				var graded := (c + tint * influence).clamp(Vector3.ZERO, Vector3.ONE)
				image.set_pixel(x, y, Color(graded.x, graded.y, graded.z))
		slices.append(image)
	var lut := ImageTexture3D.new()
	if lut.create(Image.FORMAT_RGB8, SIZE, SIZE, SIZE, false, slices) != OK: return null
	return lut
