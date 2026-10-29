extends ProgressBar
## A slanted end on the live fill, including partially depleted resources.
var tint := Color.WHITE
func _ready() -> void:
	value_changed.connect(func(_value: float): queue_redraw())
func _draw() -> void:
	var edge := size.x * clampf((value - min_value) / maxf(1.0, max_value - min_value), 0.0, 1.0)
	if edge <= 0.0: return
	var cut := minf(10.0, edge)
	var points := PackedVector2Array([Vector2.ZERO, Vector2(edge - cut, 0), Vector2(edge, size.y), Vector2(0, size.y)])
	draw_colored_polygon(points, tint)
	draw_line(Vector2.ZERO, Vector2(edge - cut, 0), tint.lightened(0.3), 1)
	draw_line(Vector2(edge - cut, 0), Vector2(edge, size.y), tint.lightened(0.3), 1)
