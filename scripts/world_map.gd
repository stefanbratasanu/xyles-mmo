extends Control
class_name XylesWorldMap

## Full-screen map of Map I. It draws from the same zone, road and landmark data
## the world builder and the enemy spawner use, so the map can never drift away
## from what the player actually walks on.
##
## North is up (-Z), east is right (+X). The sealed waygate is drawn but shown
## as locked because Map II does not exist yet.

var game: Node
var world: Node3D
var _pulse: float = 0.0
var _open_time: float = 0.0
var _bounds: Rect2 = Rect2()


func setup(game_ref: Node) -> void:
	game = game_ref
	world = game_ref.get("world") as Node3D
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	visible = false


func _process(delta: float) -> void:
	if not visible:
		return
	_pulse += delta
	queue_redraw()


func open() -> void:
	if not is_instance_valid(world):
		world = game.get("world") as Node3D
	visible = true
	_open_time = 0.0
	_bounds = _zone_bounds()
	grab_focus()
	queue_redraw()
	if is_instance_valid(game) and game.get("game_log") != null:
		game.game_log.ui("world_map_opened", {})


func close() -> void:
	visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.physical_keycode == KEY_M or event.physical_keycode == KEY_ESCAPE:
		close()
		get_viewport().set_input_as_handled()


func _draw() -> void:
	if not is_instance_valid(world):
		return
	var font: Font = get_theme_default_font()
	var map_rect := Rect2(Vector2(46.0, 62.0), size - Vector2(92.0, 126.0))
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.016, 0.023, 0.026, 1.0))
	draw_rect(map_rect, Color(0.055, 0.075, 0.070, 1.0))
	draw_rect(map_rect, Color(0.42, 0.39, 0.30, 0.95), false, 1.5)

	var bounds: Rect2 = _bounds
	if bounds.size == Vector2.ZERO:
		bounds = _zone_bounds()
		_bounds = bounds
	var scale_value: float = minf(map_rect.size.x / bounds.size.x, map_rect.size.y / bounds.size.y) * 0.94
	var map_center: Vector2 = map_rect.get_center()

	# Graticule every 20 world metres.
	var grid_color := Color(0.32, 0.38, 0.34, 0.20)
	var x: float = -80.0
	while x <= 80.0:
		var top := _map_point(Vector2(x, -92.0), map_center, scale_value)
		var bottom := _map_point(Vector2(x, 60.0), map_center, scale_value)
		draw_line(top, bottom, grid_color, 1.0, true)
		x += 20.0
	var z: float = -80.0
	while z <= 60.0:
		var left := _map_point(Vector2(-92.0, z), map_center, scale_value)
		var right := _map_point(Vector2(80.0, z), map_center, scale_value)
		draw_line(left, right, grid_color, 1.0, true)
		z += 20.0

	# Zone bodies.
	for zone: Dictionary in world.zones:
		var boundary: PackedVector2Array = world.zone_boundary(zone, 96)
		var points := PackedVector2Array()
		for point: Vector2 in boundary:
			points.append(_map_point(point, map_center, scale_value))
		var ground: Color = zone["ground"]
		var accent: Color = zone["accent"]
		draw_colored_polygon(points, Color(ground.r, ground.g, ground.b, 0.55))
		var closed := points.duplicate()
		closed.append(points[0])
		draw_polyline(closed, Color(accent.r, accent.g, accent.b, 0.85), 1.6, true)

	# Ponds.
	for pond: Dictionary in world.ponds():
		var center: Vector2 = pond["center"]
		draw_circle(_map_point(center, map_center, scale_value), maxf(3.0, float(pond["radius"]) * scale_value), Color(0.24, 0.42, 0.44, 0.85))

	# Roads: a wide soft base and a narrow pale centre line.
	for road: PackedVector2Array in world.roads:
		var points := PackedVector2Array()
		for point: Vector2 in road:
			points.append(_map_point(point, map_center, scale_value))
		if points.size() < 2:
			continue
		draw_polyline(points, Color(0.34, 0.30, 0.22, 0.95), 5.0, true)
		draw_polyline(points, Color(0.72, 0.66, 0.50, 0.95), 1.4, true)

	# Landmarks.
	var camp: Vector3 = world.camp_position
	var quest: Vector3 = world.quest_spawn
	var boss: Vector3 = world.boss_spawn
	var gate: Vector3 = world.waygate_position
	_draw_camp(_map_point(Vector2(camp.x, camp.z), map_center, scale_value), font)
	_draw_diamond(_map_point(Vector2(quest.x, quest.z), map_center, scale_value), Color("d7b46a"), "ARCH")
	_draw_diamond(_map_point(Vector2(boss.x, boss.z), map_center, scale_value), Color("b8645c"), "REGENT")
	_draw_gate(_map_point(Vector2(gate.x, gate.z), map_center, scale_value), font)

	# Zone name plates.
	for zone: Dictionary in world.zones:
		var center: Vector2 = zone["center"]
		var screen: Vector2 = _map_point(center, map_center, scale_value)
		_centered_text(font, screen + Vector2(0.0, -4.0), str(zone["name"]), 14, Color(0.93, 0.90, 0.82, 0.95))
		_centered_text(font, screen + Vector2(0.0, 12.0), world.zone_level_text(zone), 10, Color(0.78, 0.73, 0.60, 0.95))

	# Player marker.
	if is_instance_valid(game) and is_instance_valid(game.get("player")):
		var body: Node3D = game.player
		var at: Vector2 = _map_point(Vector2(body.global_position.x, body.global_position.z), map_center, scale_value)
		var pulse: float = 0.5 + sin(_pulse * 2.4) * 0.5
		draw_circle(at, 12.0 + pulse * 3.0, Color(0.93, 0.86, 0.62, 0.10))
		draw_circle(at, 4.5, Color(0.97, 0.94, 0.80, 1.0))
		draw_arc(at, 8.0, 0.0, TAU, 20, Color(0.93, 0.86, 0.62, 0.9), 1.2, true)
		var facing: float = body.rotation.y
		var tip: Vector2 = at + Vector2(sin(facing), cos(facing)) * 13.0
		var left: Vector2 = at + Vector2(sin(facing + 2.5), cos(facing + 2.5)) * 6.0
		var right: Vector2 = at + Vector2(sin(facing - 2.5), cos(facing - 2.5)) * 6.0
		draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(0.97, 0.94, 0.80, 0.9))

	# Frame text.
	var clock := ""
	var phase := ""
	if world.get("time_of_day") != null:
		clock = "%s  ·  DAY %02d" % [world.clock_text(), int(world.day_number)]
		phase = str(world.phase_text())
	draw_string(font, Vector2(48.0, 38.0), "MAP I  ·  THE ASHEN FRONTIER", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(0.93, 0.88, 0.74, 1.0))
	draw_string(font, Vector2(size.x - 260.0, 38.0), "%s  ·  %s" % [clock, phase], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.72, 0.77, 0.70, 0.95))
	_centered_text(font, Vector2(size.x * 0.5, size.y - 30.0), "M or ESC closes  ·  fast travel is not available yet", 11, Color(0.55, 0.58, 0.52, 1.0))

	# Legend.
	var legend_y: float = size.y - 62.0
	var legend_x: float = 52.0
	draw_circle(Vector2(legend_x, legend_y), 4.0, Color(0.97, 0.94, 0.80, 1.0))
	draw_string(font, Vector2(legend_x + 12.0, legend_y + 4.0), "you", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.68, 0.68, 0.60, 1.0))
	draw_rect(Rect2(Vector2(legend_x + 76.0, legend_y - 4.0), Vector2(8.0, 8.0)), Color("d7b46a"))
	draw_string(font, Vector2(legend_x + 90.0, legend_y + 4.0), "quest", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.68, 0.68, 0.60, 1.0))
	draw_colored_polygon(PackedVector2Array([
		Vector2(legend_x + 156.0, legend_y - 6.0), Vector2(legend_x + 162.0, legend_y),
		Vector2(legend_x + 156.0, legend_y + 6.0), Vector2(legend_x + 150.0, legend_y)]), Color("b8645c"))
	draw_string(font, Vector2(legend_x + 170.0, legend_y + 4.0), "boss", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.68, 0.68, 0.60, 1.0))
	draw_arc(Vector2(legend_x + 236.0, legend_y), 6.0, 0.0, TAU, 16, Color("79c3b5"), 2.0, true)
	draw_string(font, Vector2(legend_x + 248.0, legend_y + 4.0), "waygate (sealed)", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.68, 0.68, 0.60, 1.0))


func _zone_bounds() -> Rect2:
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for zone: Dictionary in world.zones:
		for point: Vector2 in world.zone_boundary(zone, 96):
			min_point = min_point.min(point)
			max_point = max_point.max(point)
	min_point -= Vector2(8.0, 8.0)
	max_point += Vector2(8.0, 8.0)
	return Rect2(min_point, max_point - min_point)


func _map_point(point: Vector2, center: Vector2, scale_value: float) -> Vector2:
	var world_center: Vector2 = _bounds.get_center()
	return center + (point - world_center) * scale_value


func _centered_text(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	var metrics: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, at - Vector2(metrics.x * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _draw_camp(at: Vector2, font: Font) -> void:
	draw_rect(Rect2(at - Vector2(6.0, 6.0), Vector2(12.0, 12.0)), Color(0.80, 0.69, 0.42, 1.0))
	draw_rect(Rect2(at - Vector2(6.0, 6.0), Vector2(12.0, 12.0)), Color(0.21, 0.19, 0.14, 1.0), false, 1.0)
	draw_string(font, at + Vector2(10.0, 4.0), "EMBERFALL CAMP", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.92, 0.85, 0.68, 1.0))


func _draw_diamond(at: Vector2, color: Color, label: String) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(at.x, at.y - 6.0), Vector2(at.x + 6.0, at.y),
		Vector2(at.x, at.y + 6.0), Vector2(at.x - 6.0, at.y)]), color)
	if label.is_empty():
		return
	var font: Font = get_theme_default_font()
	draw_string(font, at + Vector2(9.0, 4.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.78, 0.72, 0.62, 0.9))


func _draw_gate(at: Vector2, font: Font) -> void:
	var glow: float = 0.35 + sin(_pulse * 1.6) * 0.12
	draw_circle(at, 11.0, Color(0.42, 0.71, 0.65, glow * 0.35))
	draw_arc(at, 8.0, 0.0, TAU, 24, Color(0.47, 0.76, 0.69, 0.95), 2.0, true)
	draw_rect(Rect2(at - Vector2(2.4, 1.0), Vector2(4.8, 4.0)), Color(0.55, 0.80, 0.73, 0.95))
	draw_arc(at + Vector2(0.0, -1.2), 2.4, PI, TAU, 10, Color(0.55, 0.80, 0.73, 0.95), 1.4, true)
	draw_string(font, at + Vector2(12.0, 4.0), "WAYGATE  ·  SEALED", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.55, 0.78, 0.72, 0.95))
