extends TextureRect
## Isolated cosmetic preview. Never reads or writes a save or gameplay state.
signal rotation_changed(degrees: float)
const CharacterScene = preload("res://assets/models/characters/races/human_male/character.tscn")
const Adapter = preload("res://scripts/fighter_animation_adapter.gd")
const Motions = preload("res://assets/animations/player_runtime/travel_animations.res")
const POSES := ["", "idle", "walk_forward", "run"]
var viewport: SubViewport
var character: Node3D
var camera: Camera3D
var animator: AnimationPlayer
var portrait := false
var yaw := 0.0
var zoom := 1.0
var pose_index := 0
var _dragging := false
var _hidden_material: StandardMaterial3D
var model_scene: PackedScene

func _ready() -> void:
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	mouse_filter = Control.MOUSE_FILTER_STOP
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	viewport = SubViewport.new()
	viewport.name = "CharacterViewport"
	viewport.own_world_3d = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	texture = viewport.get_texture()
	character = (model_scene if model_scene != null else CharacterScene).instantiate()
	character.rotation.y = PI
	viewport.add_child(character)
	animator = character.get_node("AnimationPlayer")
	var skeleton: Skeleton3D = character.get_node("Skeleton3D")
	animator.add_animation_library(&"preview", Adapter.adapt(Motions, skeleton, character.get_meta("animation_source_rests")))
	animator.animation_finished.connect(func(_name):
		if pose_index > 0: animator.play("preview/" + POSES[pose_index]))
	camera = Camera3D.new()
	viewport.add_child(camera)
	camera.current = true
	camera.fov = 34
	_update_camera()
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-30, -140, 0)
	key.light_energy = .85
	viewport.add_child(key)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-15, 35, 0)
	fill.light_energy = .32
	viewport.add_child(fill)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("28251f")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = .55
	viewport.add_child(environment)
	_hidden_material = StandardMaterial3D.new()
	_hidden_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_hidden_material.albedo_color = Color(0, 0, 0, 0)
	_hidden_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	set_outfit_visible(false)
	resized.connect(_resize_viewport)
	gui_input.connect(_preview_input)
	_resize_viewport()

func _resize_viewport() -> void:
	if not is_instance_valid(viewport): return
	# Supersampling keeps facial detail and silhouettes clear on a large screen.
	viewport.size = Vector2i(maxi(2, roundi(size.x * 2)), maxi(2, roundi(size.y * 2)))

func set_yaw_degrees(value: float) -> void:
	yaw = clampf(value, -180.0, 180.0)
	character.rotation.y = PI + deg_to_rad(yaw)
	rotation_changed.emit(yaw)

func set_portrait(value: bool) -> void:
	portrait = value
	zoom = 1.0
	_update_camera()

func reset_view() -> void:
	set_yaw_degrees(0)
	set_portrait(false)

func _update_camera() -> void:
	var body: MeshInstance3D = character.get_node("Skeleton3D/HumanFighter")
	var bounds := body.mesh.get_aabb()
	var height := bounds.size.y
	var target := Vector3(0, bounds.end.y - height * .09, 0) if portrait else Vector3(0, bounds.position.y + height * .515, 0)
	if portrait:
		var skeleton: Skeleton3D = character.get_node("Skeleton3D")
		var head := skeleton.find_bone("humanoid_ Head")
		if head >= 0:
			target += character.global_basis * (skeleton.get_bone_global_pose(head).origin - skeleton.get_bone_global_rest(head).origin)
	camera.position = target + Vector3(0, 0, height * (-.43 if portrait else -1.85) / zoom)
	camera.look_at(target)

func _process(_delta: float) -> void:
	if portrait: _update_camera()

func set_pose(index: int) -> void:
	pose_index = clampi(index, 0, POSES.size() - 1)
	animator.stop()
	var skeleton: Skeleton3D = character.get_node("Skeleton3D")
	skeleton.reset_bone_poses()
	if pose_index > 0:
		animator.play("preview/" + POSES[pose_index])
		animator.advance(0)

func set_outfit_visible(visible: bool) -> void:
	var body: MeshInstance3D = character.get_node("Skeleton3D/HumanFighter")
	if not bool(body.mesh.get_meta("outfit_coverage", false)): return
	for surface in range(body.mesh.get_surface_count()):
		var material := body.mesh.surface_get_material(surface) as BaseMaterial3D
		if material != null and material.resource_name == "Hair": continue
		if material != null and material.albedo_texture == null:
			body.set_surface_override_material(surface, null if visible else _hidden_material)
		elif body.get_active_material(surface) is ShaderMaterial:
			(body.get_active_material(surface) as ShaderMaterial).set_shader_parameter("outfit_visible", visible)

func _preview_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
		elif event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			zoom = clampf(zoom * (1.08 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.08), .8, 1.5)
			_update_camera()
		accept_event()
	elif event is InputEventMouseMotion and _dragging:
		if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
			_dragging = false
			return
		set_yaw_degrees(wrapf(yaw + event.relative.x * .45, -180.0, 180.0))
		accept_event()
