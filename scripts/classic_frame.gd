extends PanelContainer
## Reusable bronze frame used by every floating game window.
var ornate: bool = true

func _draw() -> void:
	var r := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	draw_style_box(_rim(), r)
	if not ornate:
		return
	draw_rect(Rect2(5, 5, size.x - 10, 24), Color("24221c"))
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
