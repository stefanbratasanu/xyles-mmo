extends RefCounted
## Keep animation-pack rotations while adapting translations to the fighter's joints.
## Source libraries are shared resources and must never be edited in place.
static var _cache: Dictionary = {}

static func adapt(library: AnimationLibrary, skeleton: Skeleton3D, source_rests: Array) -> AnimationLibrary:
	# Each race has its own rest proportions. Reusing a human-sized translation
	# library on a dwarf would stretch the joints despite matching bone names.
	var rest_signature := PackedFloat32Array()
	for index in range(skeleton.get_bone_count()):
		var rest := skeleton.get_bone_rest(index)
		for vector in [rest.origin, rest.basis.x, rest.basis.y, rest.basis.z]:
			rest_signature.append_array(PackedFloat32Array([vector.x, vector.y, vector.z]))
	var cache_key := "%d:%d" % [library.get_instance_id(), hash(rest_signature)]
	if _cache.has(cache_key): return _cache[cache_key]
	var result := AnimationLibrary.new()
	for clip_name in library.get_animation_list():
		var clip := library.get_animation(clip_name).duplicate(true) as Animation
		var rotations := {}
		var positions := {}
		for track in range(clip.get_track_count()):
			var path := clip.track_get_path(track)
			if path.get_subname_count() != 1: continue
			var index := skeleton.find_bone(path.get_subname(0))
			if index < 0: continue
			var kind := clip.track_get_type(track)
			if kind == Animation.TYPE_ROTATION_3D: rotations[index] = true
			if kind == Animation.TYPE_POSITION_3D:
				positions[index] = true
				for key in range(clip.track_get_key_count(track)):
					var value: Vector3 = clip.track_get_key_value(track, key)
					clip.track_set_key_value(track, key, skeleton.get_bone_rest(index).origin + value - source_rests[index].origin)
		# Clips often omit constant bones. Their rotations must use the animation
		# pack's axes, even though the skin was bound in the fighter's A pose.
		for index in range(skeleton.get_bone_count()):
			var path := NodePath("Skeleton3D:" + String(skeleton.get_bone_name(index)))
			if not rotations.has(index):
				var track := clip.add_track(Animation.TYPE_ROTATION_3D)
				clip.track_set_path(track, path)
				clip.track_insert_key(track, 0.0, source_rests[index].basis.get_rotation_quaternion())
			if not positions.has(index):
				var track := clip.add_track(Animation.TYPE_POSITION_3D)
				clip.track_set_path(track, path)
				clip.track_insert_key(track, 0.0, skeleton.get_bone_rest(index).origin)
		result.add_animation(clip_name, clip)
	_cache[cache_key] = result
	return result
