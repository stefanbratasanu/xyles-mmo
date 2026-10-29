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
var _map_rect: Rect2 = Rect2()


func setup(game_ref: Node) -> void:
	game = game_ref
	world = game_ref.get("world") as Node3D
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
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
	_bounds = world.map_bounds() if world.has_method("map_bounds") else Rect2(-154.0, -154.0, 308.0, 308.0)
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
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.012, 0.018, 0.020, 1.0))

	var side: float = maxf(minf(size.x - 400.0, size.y - 158.0), 320.0)
	_map_rect = Rect2(Vector2(round((size.x - side) * 0.5), 92.0), Vector2(side, side))
	if _bounds.size == Vector2.ZERO:
		_bounds = world.map_bounds()
	var scale_value: float = _map_rect.size.x / _bounds.size.x

	# The map is painted from the terrain height grid and vertex colours, with a
	# hill-shade pass. There are deliberately no biome outlines: the land itself
	# carries the colour change.
	var painted: Texture2D = world.map_texture(640)
	if painted != null:
		draw_texture_rect(painted, _map_rect, false)
	else:
		draw_rect(_map_rect, Color(0.10, 0.14, 0.11, 1.0))
	draw_rect(_map_rect, Color(0.42, 0.39, 0.30, 0.95), false, 1.5)
	draw_rect(_map_rect.grow(-4.0), Color(0.10, 0.09, 0.07, 0.35), false, 1.0)

	# Roads: a dark bed with a pale centre, drawn over the painted terrain.
	for road: PackedVector2Array in world.roads:
		var points := PackedVector2Array()
		for point: Vector2 in road:
			points.append(_map_point(point))
		if points.size() < 2:
			continue
		draw_polyline(points, Color(0.20, 0.17, 0.12, 0.85), 6.0, true)
		draw_polyline(points, Color(0.73, 0.66, 0.49, 0.95), 1.9, true)

	# Pond rim, mostly for readability at small window sizes.
	for pond: Dictionary in world.ponds():
		var center: Vector2 = _map_point(pond["center"])
		draw_arc(center, maxf(4.0, float(pond["radius"]) * scale_value), 0.0, TAU, 28, Color(0.38, 0.62, 0.63, 0.55), 1.2, true)

	# Landmarks.
	var camp: Vector3 = world.camp_position
	var quest: Vector3 = world.quest_spawn
	var boss: Vector3 = world.boss_spawn
	var gate: Vector3 = world.waygate_position
	_draw_camp(_map_point(Vector2(camp.x, camp.z)), font)
	_draw_diamond(_map_point(Vector2(quest.x, quest.z)), Color("d7b46a"), "ARCH")
	# The sanctum boss spawn sits close to its zone plate, so its caption is
	# centred above the marker instead of running into the zone label.
	var boss_at: Vector2 = _map_point(Vector2(boss.x, boss.z))
	_draw_diamond(boss_at, Color("b8645c"), "")
	_centered_text(font, boss_at + Vector2(0.0, -20.0), "REGENT", 9, Color(0.78, 0.72, 0.62, 0.9))
	_draw_gate(_map_point(Vector2(gate.x, gate.z)), font)

	# Zone name plates sit on the land they describe, with a plate so the text
	# stays readable over forest or rock.
	for zone: Dictionary in world.zones:
		var center: Vector2 = _map_point(zone["center"])
		_label_plate(font, center + Vector2(0.0, -6.0), str(zone["name"]), 13, Color(0.95, 0.92, 0.84, 1.0))
		_label_plate(font, center + Vector2(0.0, 12.0), world.zone_level_text(zone), 9, Color(0.80, 0.75, 0.62, 1.0))

	# Player marker.
	if is_instance_valid(game) and is_instance_valid(game.get("player")):
		var body: Node3D = game.player
		var at: Vector2 = _map_point(Vector2(body.global_position.x, body.global_position.z))
		var pulse: float = 0.5 + sin(_pulse * 2.4) * 0.5
		draw_circle(at, 12.0 + pulse * 3.0, Color(0.93, 0.86, 0.62, 0.10))
		draw_circle(at, 4.5, Color(0.97, 0.94, 0.80, 1.0))
		draw_arc(at, 8.0, 0.0, TAU, 20, Color(0.93, 0.86, 0.62, 0.9), 1.2, true)
		var facing: float = body.rotation.y
		var tip: Vector2 = at + Vector2(sin(facing), cos(facing)) * 13.0
		var left: Vector2 = at + Vector2(sin(facing + 2.5), cos(facing + 2.5)) * 6.0
		var right: Vector2 = at + Vector2(sin(facing - 2.5), cos(facing - 2.5)) * 6.0
		draw_colored_polygon(PackedVector2Array([tip, left, right]), Color(0.97, 0.94, 0.80, 0.9))

	# Header and footer.
	var clock := ""
	var phase := ""
	if world.get("time_of_day") != null:
		clock = "%s  ·  DAY %02d" % [world.clock_text(), int(world.day_number)]
		phase = str(world.phase_text())
	draw_string(font, Vector2(44.0, 42.0), "MAP I", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(0.95, 0.90, 0.76, 1.0))
	draw_string(font, Vector2(133.0, 41.0), "THE ASHEN FRONTIER", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.68, 0.72, 0.64, 1.0))
	draw_string(font, Vector2(size.x - 300.0, 38.0), "%s  ·  %s" % [clock, phase], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0.72, 0.77, 0.70, 0.95))
	_centered_text(font, Vector2(size.x * 0.5, size.y - 26.0), "M or ESC closes  ·  fast travel is not available yet", 11, Color(0.55, 0.58, 0.52, 1.0))

	_draw_side_panels(font, scale_value)


## Region list on the left, icon legend, compass and scale bar on the right. The
## panels collapse into the map margin on narrow windows instead of covering it.
func _draw_side_panels(font: Font, scale_value: float) -> void:
	var left_x: float = 36.0
	var right_x: float = _map_rect.end.x + 34.0
	var top: float = _map_rect.position.y + 18.0
	draw_string(font, Vector2(left_x, top), "REGIONS", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.64, 0.68, 0.58, 1.0))
	var row_y: float = top + 26.0
	for zone: Dictionary in world.zones:
		var ground: Color = (zone["ground"] as Color).lightened(0.22)
		draw_circle(Vector2(left_x + 5.0, row_y - 4.0), 5.0, ground)
		draw_arc(Vector2(left_x + 5.0, row_y - 4.0), 5.0, 0.0, TAU, 12, Color(0.86, 0.82, 0.70, 0.65), 1.0, true)
		draw_string(font, Vector2(left_x + 18.0, row_y), str(zone["name"]), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.90, 0.87, 0.79, 0.96))
		draw_string(font, Vector2(left_x + 18.0, row_y + 14.0), world.zone_level_text(zone), HORIZONTAL_ALIGNMENT_LEFT, -1, 9, Color(0.66, 0.66, 0.56, 0.9))
		row_y += 42.0

	var legend_y: float = top
	draw_string(font, Vector2(right_x, legend_y), "LEGEND", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.64, 0.68, 0.58, 1.0))
	legend_y += 26.0
	draw_circle(Vector2(right_x + 5.0, legend_y - 4.0), 4.0, Color(0.97, 0.94, 0.80, 1.0))
	draw_string(font, Vector2(right_x + 18.0, legend_y), "you", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.78, 0.77, 0.68, 1.0))
	legend_y += 22.0
	draw_rect(Rect2(Vector2(right_x + 1.0, legend_y - 8.0), Vector2(8.0, 8.0)), Color("d7b46a"))
	draw_string(font, Vector2(right_x + 18.0, legend_y), "quest · ARCH", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.78, 0.77, 0.68, 1.0))
	legend_y += 22.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(right_x + 5.0, legend_y - 10.0), Vector2(right_x + 11.0, legend_y - 4.0),
		Vector2(right_x + 5.0, legend_y + 2.0), Vector2(right_x - 1.0, legend_y - 4.0)]), Color("b8645c"))
	draw_string(font, Vector2(right_x + 18.0, legend_y), "boss · REGENT", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.78, 0.77, 0.68, 1.0))
	legend_y += 22.0
	draw_arc(Vector2(right_x + 5.0, legend_y - 4.0), 6.0, 0.0, TAU, 16, Color("79c3b5"), 2.0, true)
	draw_string(font, Vector2(right_x + 18.0, legend_y), "waygate · sealed", HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color(0.78, 0.77, 0.68, 1.0))

	# Compass and scale bar.
	var compass := Vector2(right_x + 42.0, _map_rect.end.y - 108.0)
	draw_arc(compass, 24.0, 0.0, TAU, 32, Color(0.55, 0.52, 0.42, 0.7), 1.0, true)
	draw_colored_polygon(PackedVector2Array([
		compass + Vector2(0.0, -20.0), compass + Vector2(6.0, 2.0), compass + Vector2(0.0, -3.0),
		compass + Vector2(-6.0, 2.0)]), Color(0.90, 0.85, 0.70, 0.95))
	_centered_text(font, compass + Vector2(0.0, -28.0), "N", 11, Color(0.75, 0.75, 0.64, 1.0))

	var metres: float = 50.0
	var bar: float = metres * scale_value
	var bar_start := Vector2(right_x, _map_rect.end.y - 46.0)
	draw_line(bar_start, bar_start + Vector2(bar, 0.0), Color(0.78, 0.74, 0.62, 0.9), 2.0, true)
	draw_line(bar_start + Vector2(0.0, -4.0), bar_start + Vector2(0.0, 4.0), Color(0.78, 0.74, 0.62, 0.9), 1.0, true)
	draw_line(bar_start + Vector2(bar, -4.0), bar_start + Vector2(bar, 4.0), Color(0.78, 0.74, 0.62, 0.9), 1.0, true)
	draw_string(font, bar_start + Vector2(0.0, 18.0), "%d m" % int(metres), HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color(0.66, 0.66, 0.56, 0.9))


func _map_point(point: Vector2) -> Vector2:
	if _bounds.size == Vector2.ZERO:
		_bounds = world.map_bounds() if world.has_method("map_bounds") else Rect2(-154.0, -154.0, 308.0, 308.0)
	var scale_value: float = _map_rect.size.x / _bounds.size.x
	return _map_rect.position + (point - _bounds.position) * scale_value


func _centered_text(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	var metrics: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	draw_string(font, at - Vector2(metrics.x * 0.5, 0.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func _label_plate(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	var metrics: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var rect := Rect2(at - Vector2(metrics.x * 0.5 + 8.0, font_size + 2.0), Vector2(metrics.x + 16.0, font_size + 8.0))
	draw_rect(rect, Color(0.03, 0.05, 0.05, 0.55))
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
