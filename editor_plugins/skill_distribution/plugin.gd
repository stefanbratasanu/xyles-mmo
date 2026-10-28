@tool
extends EditorPlugin
var window: Window
func _enter_tree() -> void:
	add_tool_menu_item("Skill & Modifier Distribution", open_editor)
func _exit_tree() -> void:
	remove_tool_menu_item("Skill & Modifier Distribution")
	if is_instance_valid(window): window.queue_free()
func open_editor() -> void:
	if not is_instance_valid(window):
		window = preload("res://scripts/editor/skill_distribution_window.gd").new()
		get_editor_interface().get_base_control().add_child(window)
	window.popup_centered(Vector2i(1280,800))
