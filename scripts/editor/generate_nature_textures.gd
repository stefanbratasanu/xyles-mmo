extends SceneTree
## Generates the small, original tiling textures used by the frontier.
## Run with:
##   .\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script res://scripts/editor/generate_nature_textures.gd

const OUT_DIR := "res://assets/textures"


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	await _grass()
	await _grass_blades()
	await _road()
	await _bark()
	await _leaves()
	await _needles()
	print("Nature textures generated in ", OUT_DIR)
	quit()


func _noise(seed_value: int, frequency: float, octaves: int = 4, fractal: int = FastNoiseLite.FRACTAL_FBM) -> FastNoiseLite:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = frequency
	noise.fractal_type = fractal
	noise.fractal_octaves = octaves
	noise.fractal_gain = 0.52
	noise.fractal_lacunarity = 2.1
	return noise


func _seamless_image(seed_value: int, size: int, frequency: float, octaves: int = 4) -> Image:
	var texture := NoiseTexture2D.new()
	texture.width = size
	texture.height = size
	texture.seamless = true
	texture.generate_mipmaps = false
	texture.noise = _noise(seed_value, frequency, octaves)
	await texture.changed
	var image := texture.get_image()
	if image == null:
		image = Image.create(size, size, false, Image.FORMAT_RGBA8)
		image.fill(Color(0.5, 0.5, 0.5, 1.0))
	return image


func _save(name: String, image: Image) -> void:
	var path := "%s/%s.png" % [OUT_DIR, name]
	var error := image.save_png(path)
	if error != OK:
		push_error("Could not save %s (%s)" % [path, error_string(error)])
	else:
		print("Wrote ", path)


func _grass() -> void:
	var broad := await _seamless_image(1201, 512, 0.0055, 5)
	var detail := await _seamless_image(1202, 512, 0.026, 4)
	var grain := await _seamless_image(1203, 512, 0.13, 3)
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	# The grass atlas is deliberately low-saturation: the zone colour is carried by
	# the terrain vertex colours, and a green-heavy atlas used to flatten every
	# zone into the same olive meadow.
	var base := Color("4f523f")
	var dark := Color("36392c")
	var light := Color("7e8168")
	for y: int in range(512):
		for x: int in range(512):
			var broad_value: float = broad.get_pixel(x, y).r
			var detail_value: float = detail.get_pixel(x, y).r
			var grain_value: float = grain.get_pixel(x, y).r
			var color: Color = base.lerp(dark, broad_value * 0.72)
			color = color.lerp(light, detail_value * 0.42)
			color = color.lerp(light, maxf(0.0, grain_value - 0.61) * 0.9)
			color.a = 1.0
			image.set_pixel(x, y, color)
	_save("terrain_grass", image)


## A transparent atlas of individual blades. The terrain mesh still supplies the
## ground colour; these tufts give it the soft, layered silhouette that cones and
## spikes could never produce.
func _grass_blades() -> void:
	var size := 256
	var image := Image.create(size, size, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.0, 0.0, 0.0, 0.0))
	var rng := RandomNumberGenerator.new()
	rng.seed = 9107
	var palette: Array[Color] = [
		Color("5d7a3a"), Color("6f8c46"), Color("4d6a33"),
		Color("7d9852"), Color("879b55"), Color("637f3f")]
	for blade: int in range(20):
		var base_x: float = rng.randf_range(26.0, 230.0)
		var height: float = rng.randf_range(90.0, 244.0)
		var lean: float = rng.randf_range(-0.62, 0.62) * height
		var width: float = rng.randf_range(3.6, 7.0)
		var sway: float = rng.randf_range(0.0, TAU)
		var tint: Color = palette[rng.randi_range(0, palette.size() - 1)]
		var base_y: float = 254.0
		for step: int in range(int(height)):
			var t: float = float(step) / height
			var y: float = base_y - float(step)
			var x: float = base_x + lean * t * t + sin(t * 3.4 + sway) * 2.4
			var half: float = maxf(width * (1.0 - t * 0.92) * 0.5, 0.42)
			var color: Color = tint.darkened(0.28 * (1.0 - t)).lightened(0.20 * t)
			for px: int in range(int(floor(x - half)), int(ceil(x + half)) + 1):
				if px < 0 or px >= size:
					continue
				var edge: float = clampf((half - absf(float(px) - x)) / maxf(half, 0.6), 0.0, 1.0)
				var alpha: float = clampf(edge * 1.7, 0.0, 1.0)
				if alpha <= 0.05:
					continue
				var previous: Color = image.get_pixel(px, int(y))
				if alpha > previous.a:
					image.set_pixel(px, int(y), Color(color.r, color.g, color.b, alpha))
	# A handful of seed heads so the tufts are not all identical blades.
	for head: int in range(7):
		var hx: float = rng.randf_range(40.0, 216.0)
		var hy: float = rng.randf_range(36.0, 112.0)
		for dot: int in range(7):
			var ox: int = int(hx + rng.randf_range(-3.0, 3.0))
			var oy: int = int(hy + rng.randf_range(-5.0, 5.0))
			if ox < 0 or ox >= size or oy < 0 or oy >= size:
				continue
			image.set_pixel(ox, oy, Color(0.46, 0.42, 0.24, 0.9))
	_save("grass_blades", image)


func _road() -> void:
	var broad := await _seamless_image(1211, 512, 0.0075, 5)
	var ruts := await _seamless_image(1212, 512, 0.022, 4)
	var gravel := await _seamless_image(1213, 512, 0.17, 3)
	var image := Image.create(512, 512, false, Image.FORMAT_RGBA8)
	var base := Color("6b6049")
	var dark := Color("494233")
	var light := Color("91846a")
	for y: int in range(512):
		for x: int in range(512):
			var broad_value: float = broad.get_pixel(x, y).r
			# Stretch the rut sample along the road direction.
			var rut_value: float = ruts.get_pixel(x, int(y * 0.35) % 512).r
			var gravel_value: float = gravel.get_pixel(x, y).r
			var color: Color = base.lerp(dark, broad_value * 0.62 + rut_value * 0.22)
			color = color.lerp(light, maxf(0.0, gravel_value - 0.57) * 1.35)
			color.a = 1.0
			image.set_pixel(x, y, color)
	_save("terrain_road", image)


func _bark() -> void:
	var image := Image.create(256, 512, false, Image.FORMAT_RGBA8)
	var streaks := _noise(1221, 0.018, 4)
	var grain := _noise(1222, 0.15, 3)
	var base := Color("4a3828")
	var dark := Color("241b14")
	var light := Color("7b6345")
	for y: int in range(512):
		for x: int in range(256):
			# Very low frequency on Y, high on X: vertical bark fibre.
			var streak_value: float = streaks.get_noise_2d(float(x) * 1.7, float(y) * 0.14)
			var grain_value: float = grain.get_noise_2d(float(x), float(y) * 0.7)
			var value: float = clampf(streak_value * 0.5 + 0.5, 0.0, 1.0)
			var color: Color = base.lerp(dark, value * 0.85)
			color = color.lerp(light, clampf(grain_value * 0.5 + 0.5, 0.0, 1.0) * 0.24)
			color.a = 1.0
			image.set_pixel(x, y, color)
	_save("bark", image)


func _leaves() -> void:
	var broad := await _seamless_image(1231, 256, 0.018, 4)
	var detail := await _seamless_image(1232, 256, 0.075, 4)
	var speckle := await _seamless_image(1233, 256, 0.19, 3)
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var base := Color("34542a")
	var dark := Color("172b1d")
	var light := Color("7d9948")
	for y: int in range(256):
		for x: int in range(256):
			var broad_value: float = broad.get_pixel(x, y).r
			var detail_value: float = detail.get_pixel(x, y).r
			var speckle_value: float = speckle.get_pixel(x, y).r
			var color: Color = base.lerp(dark, broad_value * 0.72)
			color = color.lerp(light, detail_value * 0.62)
			color = color.lerp(light.lightened(0.12), maxf(0.0, speckle_value - 0.58) * 1.5)
			color = color.lerp(dark, maxf(0.0, 0.40 - speckle_value) * 0.8)
			color.a = 1.0
			image.set_pixel(x, y, color)
	_save("leaves", image)


func _needles() -> void:
	var broad := await _seamless_image(1241, 256, 0.02, 4)
	var detail := await _seamless_image(1242, 256, 0.1, 4)
	var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	var base := Color("253d31")
	var dark := Color("12251e")
	var light := Color("4b6444")
	for y: int in range(256):
		for x: int in range(256):
			var broad_value: float = broad.get_pixel(x, y).r
			var detail_value: float = detail.get_pixel(x, y).r
			var color: Color = base.lerp(dark, broad_value * 0.72)
			color = color.lerp(light, detail_value * 0.45)
			color.a = 1.0
			image.set_pixel(x, y, color)
	_save("needles", image)
