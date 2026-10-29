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

# Godot calls this for skill shortcuts, allowing modifiers to be highlighted.
func _make_custom_tooltip(_for_text: String) -> Object:
	if not has_meta("skill_tooltip_bbcode"):
		return null
	var panel := PanelContainer.new()
	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.custom_minimum_size.x = 300
	label.add_theme_font_size_override("normal_font_size", 12)
	label.text = str(get_meta("skill_tooltip_bbcode"))
	panel.add_child(label)
	return panel
