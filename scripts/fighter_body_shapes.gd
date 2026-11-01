extends Node3D
## Cosmetic appearance. Builds change only silhouette, never combat or collision.
const SIZE_NAMES := ["Very skinny", "Slim", "Average", "Fat", "Very fat"]
const MUSCLE_NAMES := ["No visible muscle", "Lightly toned", "Athletic", "Muscular", "Very muscular"]
const SURFACE_SHADER = preload("res://scripts/fighter_body_surface.gdshader")
var _skin_materials: Array[ShaderMaterial] = []

@export_range(0, 4) var body_size: int = 2:
	set(value):
		body_size = clampi(value, 0, 4)
		if is_node_ready(): apply_body_shape()
@export_range(0, 4) var muscularity: int = 3:
	set(value):
		muscularity = clampi(value, 0, 4)
		if is_node_ready(): apply_body_shape()
func _ready() -> void:
	initialize_body()

func initialize_body() -> void:
	_skin_materials.clear()
	var body := get_node_or_null("Skeleton3D/HumanFighter") as MeshInstance3D
	if body == null: return
	for surface in range(body.mesh.get_surface_count()):
		var original := body.mesh.surface_get_material(surface) as BaseMaterial3D
		if original == null: continue
		if original.albedo_texture == null:
			if original.resource_name == "Hair":
				# Match the bald fighter reference in preview and gameplay.
				var hidden_hair := original.duplicate() as BaseMaterial3D
				hidden_hair.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				hidden_hair.albedo_color.a = 0.0
				body.set_surface_override_material(surface, hidden_hair)
			# Cloth, hair and metal are unchanged across instances; only the
			# body surfaces need the per-instance softness shader.
			continue
		var material := ShaderMaterial.new()
		material.shader = SURFACE_SHADER
		material.set_shader_parameter("skin_texture", original.albedo_texture)
		material.set_shader_parameter("coverage_enabled", surface == 0 and bool(body.mesh.get_meta("outfit_coverage", false)))
		body.set_surface_override_material(surface, material)
		_skin_materials.append(material)
	apply_body_shape()

func apply_body_shape() -> void:
	var body := get_node_or_null("Skeleton3D/HumanFighter") as MeshInstance3D
	if body == null: return
	# Neutral 2/3 is the basis. Every other build has one complete target.
	var selected := "Physique_%d_%d" % [body_size, muscularity]
	for index in range(body.mesh.get_blend_shape_count()):
		body.set_blend_shape_value(index, 1.0 if body.mesh.get_blend_shape_name(index) == selected else 0.0)
	var low_muscle := maxf(0.0, (3.0 - muscularity) / 3.0)
	var fat := maxf(0.0, (body_size - 2.0) / 2.0)
	var softness := maxf(low_muscle, fat * 0.96)
	for material in _skin_materials:
		material.set_shader_parameter("softness", softness)
