extends Node3D
## Preallocated effects: combat reuses meshes, materials, lights and instances.
var rings: Array[MeshInstance3D] = []
var orbs: Array[MeshInstance3D] = []
var labels: Array[Label3D] = []
var orb_mesh: SphereMesh
var orb_material: StandardMaterial3D

func prepare(at: Vector3) -> void:
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.85
	ring_mesh.outer_radius = 1.0
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 8
	for i in range(24):
		var ring := MeshInstance3D.new()
		ring.mesh = ring_mesh
		var material := StandardMaterial3D.new()
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.albedo_color = Color(1, 1, 1, 0.01)
		ring.material_override = material
		ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(ring)
		ring.position = at + Vector3.UP
		ring.scale = Vector3.ONE * 0.001
		ring.set_meta("busy", false)
		rings.append(ring)
	orb_mesh = SphereMesh.new()
	orb_mesh.radius = 0.18
	orb_mesh.height = 0.36
	orb_mesh.radial_segments = 16
	orb_mesh.rings = 8
	orb_material = StandardMaterial3D.new()
	orb_material.albedo_color = Color("ffa765")
	orb_material.emission_enabled = true
	orb_material.emission = Color("f99a4c")
	orb_material.emission_energy_multiplier = 4.0
	for i in range(6):
		var orb := _new_orb()
		orb.position = at + Vector3.UP
		orb.scale = Vector3.ONE * 0.001
	for i in range(32):
		var label := Label3D.new()
		label.text = "0123456789+-GUARD"
		label.font_size = 38
		label.pixel_size = 0.008
		label.outline_size = 4
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.position = at + Vector3.UP
		label.scale = Vector3.ONE * 0.001
		label.set_meta("busy", false)
		add_child(label)
		labels.append(label)
	# Draw tiny instances at startup so the renderer sees the effect variants
	# before the first action. Invisible objects alone do not warm pipelines.
	_finish_warmup()

func _finish_warmup() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	for instance in rings + orbs + labels:
		if not instance.get_meta("busy", false):
			instance.hide()

func floating_text(at: Vector3, text_value: String, color: Color) -> void:
	var label: Label3D
	for candidate in labels:
		if not candidate.get_meta("busy", false):
			label = candidate
			break
	if label == null:
		return
	label.set_meta("busy", true)
	label.position = at
	label.scale = Vector3.ONE
	label.text = text_value
	label.modulate = color
	label.show()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(label, "position", at + Vector3.UP * 1.6, 1.0)
	tween.tween_property(label, "modulate:a", 0.0, 0.7).set_delay(0.3)
	tween.chain().tween_callback(func():
		label.hide()
		label.set_meta("busy", false)
	)

func _new_orb() -> MeshInstance3D:
	var orb := MeshInstance3D.new()
	orb.mesh = orb_mesh
	orb.material_override = orb_material
	orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var light := OmniLight3D.new()
	light.light_color = Color("ffc47c")
	light.light_energy = 2.0
	light.omni_range = 3.0
	orb.add_child(light)
	orb.set_meta("busy", false)
	add_child(orb)
	orbs.append(orb)
	return orb

func take_orb() -> MeshInstance3D:
	for orb in orbs:
		if not orb.get_meta("busy", false):
			orb.set_meta("busy", true)
			orb.scale = Vector3.ONE
			orb.show()
			return orb
	# Preserve projectile behavior even under unusual bursts of simultaneous casts.
	var extra := _new_orb()
	extra.set_meta("busy", true)
	return extra

func release_orb(orb: MeshInstance3D) -> void:
	orb.hide()
	orb.set_meta("busy", false)

func burst(at: Vector3, color: Color, radius: float, duration: float) -> void:
	var ring: MeshInstance3D
	for candidate in rings:
		if not candidate.get_meta("busy", false):
			ring = candidate
			break
	if ring == null:
		return # Only skip excess cosmetic rings; combat damage is independent.
	ring.set_meta("busy", true)
	ring.position = at + Vector3.UP * 0.09
	ring.scale = Vector3.ONE * 0.15
	var material: StandardMaterial3D = ring.material_override
	material.albedo_color = color
	ring.show()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(radius, 0.6, radius), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(material, "albedo_color:a", 0.0, duration)
	tween.chain().tween_callback(func():
		ring.hide()
		ring.set_meta("busy", false)
	)
