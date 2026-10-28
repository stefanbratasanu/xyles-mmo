extends Node3D
## Small native-mesh character art kit. Forward is -Z.

var left_leg: Node3D
var right_leg: Node3D
var left_arm: Node3D
var right_arm: Node3D
var cloak: MeshInstance3D
var gait: float = 0.0
var strike: float = 0.0
var wolf: bool = false
var boar: bool = false
var base_color: Color

func _mat(color: Color, metal: float = 0.0, glow: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = metal
	m.roughness = 0.7 if metal < 0.5 else 0.4
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	return m

func _mesh(mesh: Mesh, at: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	parent.add_child(instance)
	return instance

func _box(size_value: Vector3, at: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size_value
	return _mesh(mesh, at, material, parent)

func _sphere(radius: float, at: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 5
	return _mesh(mesh, at, material, parent)

func _cylinder(bottom: float, top: float, height: float, at: Vector3, material: Material, parent: Node3D = self) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = 8
	return _mesh(mesh, at, material, parent)

func build_knight(color: Color = Color("31535b"), is_boss: bool = false) -> void:
	base_color = color
	var steel := _mat(Color("728186"), 0.72)
	var dark := _mat(Color("202c31"), 0.65)
	var trim := _mat(Color("b39b62"), 0.7)
	var cloth := _mat(color)
	var leather := _mat(Color("292929"))
	var eye := _mat(Color("83dce1") if not is_boss else Color("db88ef"), 0.0, 2.0)
	_cylinder(0.29, 0.36, 0.62, Vector3(0, 1.14, 0), steel)
	_box(Vector3(0.51, 0.13, 0.36), Vector3(0, 0.9, 0), trim)
	_cylinder(0.38, 0.24, 0.42, Vector3(0, 0.7, 0), cloth)
	_box(Vector3(0.09, 0.52, 0.06), Vector3(0, 1.13, -0.315), trim)
	_box(Vector3(0.34, 0.08, 0.06), Vector3(0, 1.3, -0.28), trim)
	_sphere(0.225, Vector3(0, 1.69, 0), steel)
	_cylinder(0.23, 0.18, 0.25, Vector3(0, 1.64, 0), dark)
	_box(Vector3(0.35, 0.045, 0.08), Vector3(0, 1.7, -0.205), eye)
	_box(Vector3(0.055, 0.26, 0.08), Vector3(0, 1.66, -0.265), trim)
	_box(Vector3(0.08, 0.17, 0.30), Vector3(0, 1.94, 0.03), cloth)
	left_leg = Node3D.new()
	left_leg.position = Vector3(-0.18, 0.7, 0)
	add_child(left_leg)
	right_leg = Node3D.new()
	right_leg.position = Vector3(0.18, 0.7, 0)
	add_child(right_leg)
	for leg in [left_leg, right_leg]:
		_box(Vector3(0.23, 0.49, 0.25), Vector3(0, -0.24, 0), dark, leg)
		_box(Vector3(0.26, 0.22, 0.37), Vector3(0, -0.53, -0.05), steel, leg)
		_box(Vector3(0.2, 0.13, 0.06), Vector3(0, -0.19, -0.14), trim, leg)
	left_arm = Node3D.new()
	left_arm.position = Vector3(-0.43, 1.35, 0)
	add_child(left_arm)
	right_arm = Node3D.new()
	right_arm.position = Vector3(0.43, 1.35, 0)
	add_child(right_arm)
	for arm in [left_arm, right_arm]:
		_sphere(0.22, Vector3.ZERO, steel, arm)
		_box(Vector3(0.19, 0.46, 0.21), Vector3(0, -0.27, 0), dark, arm)
		_box(Vector3(0.22, 0.21, 0.24), Vector3(0, -0.40, -0.03), steel, arm)
	_box(Vector3(0.09, 0.28, 0.09), Vector3(0.03, -0.58, -0.08), leather, right_arm)
	_box(Vector3(0.40, 0.07, 0.12), Vector3(0.03, -0.44, -0.08), trim, right_arm)
	var blade := _box(Vector3(0.11, 0.91, 0.065), Vector3(0.03, 0.04, -0.08), steel, right_arm)
	blade.rotation.z = -0.07
	_box(Vector3(0.36, 0.66, 0.11), Vector3(-0.05, -0.23, -0.18), dark, left_arm)
	_box(Vector3(0.28, 0.055, 0.03), Vector3(-0.05, -0.19, -0.245), trim, left_arm)
	_box(Vector3(0.05, 0.51, 0.03), Vector3(-0.05, -0.19, -0.245), trim, left_arm)
	cloak = _box(Vector3(0.67, 0.90, 0.075), Vector3(0, 0.99, 0.3), cloth)
	cloak.rotation.x = -0.13
	if is_boss:
		for side in [-1.0, 1.0]:
			var horn := _cylinder(0.07, 0.018, 0.75, Vector3(side * 0.28, 2.08, 0.05), trim)
			horn.rotation.z = side * -0.6
			var branch := _cylinder(0.05, 0.008, 0.4, Vector3(side * 0.49, 2.22, -0.04), trim)
			branch.rotation.z = side * 0.5

func _fur_card_material(tint: Color) -> StandardMaterial3D:
	# The Blender cards are exported as blended transparency, which sorts badly
	# and drops shadows. The project's foliage uses alpha scissor + alpha to
	# coverage, so the fur gets the same treatment and keeps solid shadowing.
	var material := StandardMaterial3D.new()
	material.resource_name = "FurCard"
	material.albedo_texture = load("res://assets/textures/fur_card.png")
	material.albedo_color = tint
	material.roughness = 0.95
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	material.alpha_scissor_threshold = 0.34
	material.alpha_antialiasing_mode = BaseMaterial3D.ALPHA_ANTIALIASING_ALPHA_TO_COVERAGE
	material.alpha_antialiasing_edge = 0.55
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	material.diffuse_mode = BaseMaterial3D.DIFFUSE_LAMBERT_WRAP
	return material


func _apply_fur_cards(model: Node3D, tint: Color) -> void:
	var material := _fur_card_material(tint)
	var replaced: int = 0
	for node: Node in model.find_children("*", "MeshInstance3D", true, false):
		var instance := node as MeshInstance3D
		if instance.mesh == null:
			continue
		for surface: int in range(instance.mesh.get_surface_count()):
			var current: Material = instance.get_surface_override_material(surface)
			if current == null:
				current = instance.mesh.surface_get_material(surface)
			if current == null:
				continue
			var card := String(current.resource_name).begins_with("FurCard")
			if not card and current is BaseMaterial3D:
				var base := current as BaseMaterial3D
				card = base.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
			if card:
				instance.set_surface_override_material(surface, material)
				replaced += 1
	if replaced == 0:
		push_warning("fur cards were not found in %s" % model.name)


func _load_creature(file_name: String, fur_tint: Color) -> bool:
	# The Blender-built wolf/boar carry a UV-unwrapped fur/hide texture. Keep the
	# procedural primitive build below as a fallback so a missing or failed GLB
	# can never leave a normal enemy invisible.
	var packed: PackedScene = load("res://assets/models/creatures/" + file_name) as PackedScene
	if packed == null:
		return false
	var model := packed.instantiate()
	if model == null:
		return false
	add_child(model)
	_apply_fur_cards(model, fur_tint)
	return true


func build_wolf() -> void:
	wolf = true
	if _load_creature("wolf.glb", Color("7b766a")):
		return
	var fur := _mat(Color("444a3d"))
	var mane := _mat(Color("67735a"))
	var black := _mat(Color("161d1b"))
	var glow := _mat(Color("dc9750"), 0, 1.5)
	var body := _sphere(0.47, Vector3(0, 0.7, 0.06), fur)
	body.scale = Vector3(0.8, 0.85, 1.5)
	var head := _sphere(0.31, Vector3(0, 0.98, -0.62), mane)
	head.scale = Vector3(1.0, 1.0, 1.24)
	_box(Vector3(0.28, 0.20, 0.42), Vector3(0, 0.87, -0.93), fur)
	_box(Vector3(0.22, 0.13, 0.10), Vector3(0, 0.9, -1.16), black)
	for side in [-1.0, 1.0]:
		var ear := _cylinder(0.12, 0.0, 0.28, Vector3(side * 0.20, 1.29, -0.56), mane)
		ear.rotation.z = side * -0.2
		_sphere(0.046, Vector3(side * 0.255, 1.02, -0.82), glow)
		for z in [-0.42, 0.43]:
			_box(Vector3(0.15, 0.58, 0.17), Vector3(side * 0.26, 0.36, z), fur)
			_box(Vector3(0.19, 0.13, 0.29), Vector3(side * 0.26, 0.10, z - 0.06), black)
	var tail := _cylinder(0.14, 0.03, 0.73, Vector3(0, 0.75, 0.89), mane)
	tail.rotation.x = 1.1
	for i in range(5):
		var thorn := _cylinder(0.07, 0, 0.30, Vector3(0, 1.02, 0.5 - i * 0.18), mane)
		thorn.rotation.x = -0.45

## A low, broad-bodied ridge boar: heavy shoulder hump, short snout, paired
## tusks and bristles down the spine. Forward is -Z, same as the wolf.
func build_boar() -> void:
	boar = true
	if _load_creature("boar.glb", Color("8f6a47")):
		return
	var hide := _mat(Color("5a4636"))
	var ridge := _mat(Color("725b44"))
	var dark := _mat(Color("241d18"))
	var tusk := _mat(Color("d8c9a4"))
	var eye := _mat(Color("c9834a"), 0, 1.2)
	var body := _sphere(0.62, Vector3(0, 0.82, 0.08), hide)
	body.scale = Vector3(0.92, 0.78, 1.32)
	var hump := _sphere(0.44, Vector3(0, 1.12, -0.18), ridge)
	hump.scale = Vector3(0.9, 0.75, 0.9)
	var head := _sphere(0.34, Vector3(0, 0.86, -0.78), hide)
	head.scale = Vector3(0.95, 0.88, 1.05)
	_box(Vector3(0.34, 0.26, 0.46), Vector3(0, 0.78, -1.06), ridge)
	_box(Vector3(0.22, 0.14, 0.16), Vector3(0, 0.76, -1.31), dark)
	for side in [-1.0, 1.0]:
		var ear := _cylinder(0.10, 0.0, 0.22, Vector3(side * 0.22, 1.09, -0.74), dark)
		ear.rotation.z = side * -0.35
		_sphere(0.04, Vector3(side * 0.25, 0.94, -0.94), eye)
		var tusk_mesh := _cylinder(0.045, 0.005, 0.30, Vector3(side * 0.16, 0.78, -1.22), tusk)
		tusk_mesh.rotation.x = -1.05
		tusk_mesh.rotation.z = side * 0.22
		for z in [-0.44, 0.44]:
			_box(Vector3(0.19, 0.46, 0.20), Vector3(side * 0.34, 0.30, z), dark)
			_box(Vector3(0.22, 0.11, 0.25), Vector3(side * 0.34, 0.08, z - 0.04), dark)
	for i in range(6):
		var bristle := _cylinder(0.045, 0.0, 0.26, Vector3(0, 1.31 - i * 0.03, -0.34 + i * 0.15), ridge)
		bristle.rotation.x = -0.35
	var tail := _cylinder(0.055, 0.02, 0.34, Vector3(0, 0.92, 0.88), dark)
	tail.rotation.x = 0.9


func animate(delta: float, speed_value: float, attacking: bool = false) -> void:
	gait += delta * speed_value * 2.6
	strike = move_toward(strike, 0.0, delta * 5.5)
	if attacking:
		strike = 1.0
	if wolf or boar:
		position.y = absf(sin(gait)) * minf(speed_value * 0.03, 0.12)
		if boar:
			# A heavy roll in the shoulders sells the charge without a rig.
			rotation.z = sin(gait * 0.5) * minf(speed_value * 0.018, 0.08)
		return
	if left_leg:
		var angle: float = sin(gait) * minf(speed_value * 0.13, 0.6)
		left_leg.rotation.x = angle
		right_leg.rotation.x = -angle
		left_arm.rotation.x = -angle * 0.5
		right_arm.rotation.x = angle * 0.5 - sin(strike * PI) * 2.1
		right_arm.rotation.z = sin(strike * PI) * -0.9
		cloak.rotation.x = -0.14 - absf(angle) * 0.3
