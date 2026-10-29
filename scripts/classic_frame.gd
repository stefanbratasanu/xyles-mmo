extends PanelContainer
## Reusable bronze frame used by every floating game window.
var ornate: bool = true
var angled_status: bool = false
var interior_color := Color(0.085, 0.078, 0.065, 0.86)

func _draw() -> void:
	if angled_status:
		var outline := PackedVector2Array([Vector2(1, 1), Vector2(size.x - 48, 1), size - Vector2.ONE, Vector2(1, size.y - 1)])
		draw_colored_polygon(outline, interior_color)
		outline.append(outline[0])
		draw_polyline(outline, Color("a1977b"), 1, true)
		return
	var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	draw_style_box(_rim(), r)
	# Inset bevel: warm metal outside, dark recessed content inside.
	draw_rect(Rect2(5, 5, size.x - 10, size.y - 10), Color("39352b"), false, 1)
	draw_line(Vector2(7, 6), Vector2(size.x - 7, 6), Color("a1977b"), 1)
	draw_line(Vector2(6, size.y - 6), size - Vector2(6, 6), Color("080908"), 1)
	if not ornate:
		return
	draw_rect(Rect2(5, 5, size.x - 10, 24), Color("24221c"))
	for y in range(7, 27):
		draw_line(Vector2(8, y), Vector2(size.x - 8, y), Color(0.65, 0.58, 0.39, 0.12 * (1.0 - float(y - 7) / 20.0)), 1)
	draw_line(Vector2(8, 29), Vector2(size.x - 8, 29), Color("514a3a"), 1)
	var bronze := Color("a79879")
	var light := Color("dbceb0")
	for corner in [Vector2(4, 4), Vector2(size.x - 4, 4), Vector2(4, size.y - 4), size - Vector2(4, 4)]:
		var direction := Vector2(1 if corner.x < size.x * 0.5 else -1, 1 if corner.y < size.y * 0.5 else -1)
		var points := PackedVector2Array()
		for p in [Vector2(0, 20), Vector2(3, 14), Vector2(1, 8), Vector2(7, 2), Vector2(15, 3), Vector2(21, 0)]:
			points.append(corner + p * direction)
		draw_polyline(points, bronze, 2, true)
		draw_line(corner + Vector2(3, 12) * direction, corner + Vector2(12, 3) * direction, light, 1, true)
	var c := Vector2(size.x * 0.5, 3)
	draw_polyline(PackedVector2Array([c + Vector2(-48, 0), c + Vector2(-31, 4), c + Vector2(-16, 1), c + Vector2(-7, -3), c, c + Vector2(7, -3), c + Vector2(16, 1), c + Vector2(31, 4), c + Vector2(48, 0)]), bronze, 2, true)
	draw_polyline(PackedVector2Array([c + Vector2(-12, 0), c + Vector2(0, -7), c + Vector2(12, 0)]), light, 1, true)

func _rim() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color.TRANSPARENT
	style.border_color = Color("776d58")
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	return style
