extends Button
var drag_payload: Dictionary = {}
var drop_handler: Callable
func _get_drag_data(_at: Vector2) -> Variant:
	if drag_payload.is_empty(): return null
	var preview := Label.new()
	preview.text = text if not text.is_empty() else str(drag_payload.get("id",""))
	set_drag_preview(preview)
	return drag_payload.duplicate()
func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return drop_handler.is_valid() and data is Dictionary and data.get("kind","") == "hotbar"
func _drop_data(_at: Vector2, data: Variant) -> void:
	if _can_drop_data(_at,data): drop_handler.call(data)
