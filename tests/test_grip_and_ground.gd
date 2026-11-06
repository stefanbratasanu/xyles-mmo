extends SceneTree
var failures := 0
var game: Node
var contact_frames := 0
var worst_penetration := 0.0
var stationary_gap := 0.0
var measuring_idle := true
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func _initialize() -> void: call_deferred("run")
func inspect_contact() -> void:
	var p = game.player
	if not p.is_on_floor() or p.action_active: return
	contact_frames += 1
	if contact_frames % 5 != 0: return
	var rig: Skeleton3D = p.fighter_visual.get_node(p.fighter_visual.skeleton)
	var skin: Skin = p.fighter_visual.skin
	var binds: Array[Transform3D] = []
	for i in range(skin.bind_count): binds.append(rig.get_bone_global_pose(skin.get_bind_bone(i)) * skin.get_bind_pose(i))
	for side in ["L", "R"]:
		var minimum := INF
		for sample: Dictionary in p.foot_modifier.samples[side]:
			var v := Vector3.ZERO
			for j in range(sample.weights.size()): v += (binds[sample.bones[j]] * sample.point) * float(sample.weights[j])
			var point := rig.to_global(v)
			minimum = minf(minimum, point.y - game.world.foot_ground_height(point.x, point.z))
		worst_penetration = minf(worst_penetration, minimum)
		if measuring_idle: stationary_gap = maxf(stationary_gap, minimum)
func run() -> void:
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	game.debug_invulnerable = true
	for enemy in game.enemies: enemy.set_physics_process(false)
	for i in range(60): await physics_frame
	var p = game.player
	check(p.is_on_floor(), "Player settles on the terrain")
	p.foot_modifier.modification_processed.connect(inspect_contact)
	for i in range(30): await physics_frame
	check(contact_frames > 10 and worst_penetration > -.012 and stationary_gap < .015, "Both idle soles stay within 1.5 cm of the visible camp surface")
	measuring_idle = false
	contact_frames = 0
	var start := Vector3(13, 0, 100)
	start.y = game.world.surface_height_at(start.x, start.z) + .25
	game.world.update_terrain_chunks(start)
	p.global_position = start
	p.velocity = Vector3.ZERO
	for i in range(30): await physics_frame
	p.destination = Vector3(22, start.y, start.z)
	p.moving_to_click = true
	for i in range(160): await physics_frame
	check(p.global_position.x > 18.0 and contact_frames > 30, "Grounding remains active while crossing uneven streamed terrain")
	check(worst_penetration > -.06, "Sole samples avoid deep terrain penetration during traversal")
	p.moving_to_click = false
	p.foot_modifier.modification_processed.disconnect(inspect_contact)
	var rig: Skeleton3D = p.fighter_visual.get_node(p.fighter_visual.skeleton)
	var models = load("res://scripts/character_models.gd")
	var entries: Array = JSON.parse_string(FileAccess.get_file_as_string(models.MANIFEST)).models
	var anchor = load("res://scripts/weapon_anchor.gd")
	for model: Dictionary in entries:
		p.apply_character_appearance({}, model.race, model.gender)
		check(p.foot_modifier.samples.L.size() > 0 and p.foot_modifier.samples.R.size() > 0, model.id + ": both feet have sole samples")
		contact_frames = 0
		worst_penetration = 0.0
		stationary_gap = 0.0
		measuring_idle = true
		p.foot_modifier.modification_processed.connect(inspect_contact)
		for i in range(15): await physics_frame
		p.foot_modifier.modification_processed.disconnect(inspect_contact)
		check(contact_frames > 5 and worst_penetration > -.05 and stationary_gap < .07, model.id + ": both feet contact uneven terrain")
		var inv := rig.get_bone_global_rest(rig.find_bone("humanoid_ R Hand")).affine_inverse()
		var a := (inv * rig.get_bone_global_rest(rig.find_bone("humanoid_ R Finger1"))).origin
		var b := (inv * rig.get_bone_global_rest(rig.find_bone("humanoid_ R Finger4"))).origin
		for pair in [["sword", ""], ["sword", "ornate_silver_sword"], ["greatsword", ""], ["staff", ""], ["spear", ""], ["bow", ""]]:
			var weapon: Node3D = p.create_weapon_visual(pair[0], pair[1])
			p.weapon_attachment.add_child(weapon)
			check(anchor.apply(rig, weapon, pair[0], pair[1]), model.id + ": anchor available")
			var contact: Vector3 = anchor.CONTACTS.get(pair[1], anchor.CONTACTS[pair[0]])
			var palm: Marker3D = p.weapon_attachment.get_node("PalmGripAnchor")
			check((weapon.transform * contact).distance_to(palm.position) < .0001, model.id + ": handle meets palm for " + str(pair))
			check(palm.position.distance_to((a+b)*.5) > .008 and palm.position.distance_to((a+b)*.5) < .08, model.id + ": contact sits outside the palm near the curled fingers")
			check(weapon.basis.y.dot((a-b).normalized()) > .99, model.id + ": handle follows fingers for " + str(pair))
			weapon.free()
	var marked := Node3D.new()
	var marker := Marker3D.new()
	marker.name = "GripAnchor"
	marker.position = Vector3(.2, -.12, .03)
	marker.rotation_degrees = Vector3(10, 25, 40)
	marked.add_child(marker)
	p.weapon_attachment.add_child(marked)
	check(anchor.apply(rig, marked, "sword", ""), "Custom weapon marker can be used")
	var aligned: Transform3D = marked.transform * marker.transform
	var inv_hand := rig.get_bone_global_rest(rig.find_bone("humanoid_ R Hand")).affine_inverse()
	var first := (inv_hand * rig.get_bone_global_rest(rig.find_bone("humanoid_ R Finger1"))).origin
	var last := (inv_hand * rig.get_bone_global_rest(rig.find_bone("humanoid_ R Finger4"))).origin
	check(aligned.origin.distance_to(p.weapon_attachment.get_node("PalmGripAnchor").position) < .0001 and aligned.basis.y.dot((first-last).normalized()) > .99, "Authored marker position and orientation both align")
	marked.free()
	# The actual skeleton solver must move the ankle in the requested direction.
	p.apply_character_appearance({}, "Human", "Male")
	p.animation_player.play("travel/carry_idle")
	p.animation_player.seek(.2, true)
	rig.force_update_all_bone_transforms()
	var foot := rig.find_bone("humanoid_ L Foot")
	var before := rig.to_global(rig.get_bone_global_pose(foot).origin)
	p.foot_modifier._adjust_leg(rig, "L", .05)
	var after := rig.to_global(rig.get_bone_global_pose(foot).origin)
	check(after.y > before.y + .035, "Leg IK raises an intersecting foot")
	check(after.distance_to(before + Vector3.UP * .05) < .015, "Leg IK reaches the requested contact")
	print("GRIP AND GROUND: ", failures, " failures; ", entries.size(), " models, six weapon variants")
	game.queue_free(); await process_frame; quit(failures)
