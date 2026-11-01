extends RefCounted
## Hand-local weapon calibration, shared by characters using the same model.
var path := "res://resources/characters/weapon_grips.cfg"
var config := ConfigFile.new()

func load_grips() -> void:
	config = ConfigFile.new()
	config.load(path)

func apply(key: String, weapon: Node3D) -> void:
	var position: Variant = config.get_value(key, "position", weapon.position)
	var rotation: Variant = config.get_value(key, "rotation_degrees", weapon.rotation_degrees)
	if position is Vector3 and position.is_finite(): weapon.position = position
	if rotation is Vector3 and rotation.is_finite(): weapon.rotation_degrees = rotation

func hand_rotation(key: String) -> Vector3:
	var value: Variant = config.get_value(key, "hand_rotation_degrees", Vector3.ZERO)
	return value if value is Vector3 and value.is_finite() else Vector3.ZERO

func save_grip(key: String, weapon: Node3D, hand: Vector3 = Vector3.ZERO) -> Error:
	if not weapon.position.is_finite() or not weapon.rotation_degrees.is_finite() or not hand.is_finite(): return ERR_INVALID_DATA
	# Save a copy so a failed write cannot silently become an active saved grip.
	var next := ConfigFile.new()
	next.parse(config.encode_to_text())
	next.set_value(key, "position", weapon.position)
	next.set_value(key, "rotation_degrees", weapon.rotation_degrees)
	next.set_value(key, "hand_rotation_degrees", hand)
	var error := next.save(path)
	if error == OK: config = next
	return error
