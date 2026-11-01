extends RefCounted
## Editable, bounded height field. Cells may be absent so a cleared map can
## start without ground; visible geometry and collision use the same triangles.

var segments: int = 0
var extent: float = 0.0
var heights := PackedFloat32Array()
var colors := PackedColorArray()
var surfaces := PackedByteArray()
var cells := PackedByteArray()

func initialize(size: int, half_extent: float, fill: bool = true) -> Error:
	if size < 1 or size > 1024 or not is_finite(half_extent) or half_extent <= 0.0:
		return ERR_INVALID_PARAMETER
	segments = size
	extent = half_extent
	var vertices := (segments + 1) * (segments + 1)
	heights.resize(vertices)
	colors.resize(vertices)
	colors.fill(Color.WHITE)
	surfaces.resize(vertices)
	cells.resize(segments * segments)
	cells.fill(1 if fill else 0)
	return OK

func import_baked(data: Resource) -> Error:
	if data == null or int(data.terrain_grid_size) != int(data.terrain_segments) + 1:
		return ERR_INVALID_DATA
	var error := initialize(int(data.terrain_segments), float(data.terrain_extent))
	if error != OK:
		return error
	if data.terrain_heights.size() != heights.size() or data.terrain_colors.size() != colors.size():
		return ERR_INVALID_DATA
	heights = data.terrain_heights.duplicate()
	colors = data.terrain_colors.duplicate()
	return OK

func _index(x: int, z: int) -> int:
	return z * (segments + 1) + x

func _vertex(x: int, z: int) -> Vector2:
	var step := extent * 2.0 / float(segments)
	return Vector2(-extent + x * step, -extent + z * step)

## Matches the triangle split in bake_world.gd and surface_height_at().
## NAN means there is no terrain at the requested point.
func sample_height(point: Vector2) -> float:
	if segments < 1 or absf(point.x) > extent or absf(point.y) > extent:
		return NAN
	var step := extent * 2.0 / float(segments)
	var gx := (point.x + extent) / step
	var gz := (point.y + extent) / step
	var x := clampi(floori(gx), 0, segments - 1)
	var z := clampi(floori(gz), 0, segments - 1)
	if cells[z * segments + x] == 0:
		return NAN
	var u := clampf(gx - x, 0.0, 1.0)
	var v := clampf(gz - z, 0.0, 1.0)
	var a := heights[_index(x, z)]
	var b := heights[_index(x + 1, z)]
	var c := heights[_index(x, z + 1)]
	var d := heights[_index(x + 1, z + 1)]
	if u + v <= 1.0:
		return a + u * (b - a) + v * (c - a)
	return b * (1.0 - v) + d * (u + v - 1.0) + c * (1.0 - u)

func clear() -> void:
	cells.fill(0)
	heights.fill(0.0)
	colors.fill(Color.WHITE)
	surfaces.fill(0)

## Add or erase terrain cells with a circular brush. Ground is added at the
## current vertex heights, which default to zero after clearing.
func paint_ground(center: Vector2, radius: float, present: bool) -> void:
	if segments < 1 or not is_finite(radius) or radius <= 0.0:
		return
	var step := extent * 2.0 / float(segments)
	var min_x := clampi(floori((center.x - radius + extent) / step), 0, segments - 1)
	var max_x := clampi(floori((center.x + radius + extent) / step), 0, segments - 1)
	var min_z := clampi(floori((center.y - radius + extent) / step), 0, segments - 1)
	var max_z := clampi(floori((center.y + radius + extent) / step), 0, segments - 1)
	for z in range(min_z, max_z + 1):
		for x in range(min_x, max_x + 1):
			var midpoint := _vertex(x, z) + Vector2.ONE * step * 0.5
			if midpoint.distance_squared_to(center) <= radius * radius:
				cells[z * segments + x] = 1 if present else 0

## Strength is metres at the brush centre; callers multiply by elapsed time.
func sculpt(center: Vector2, radius: float, strength: float) -> void:
	if segments < 1 or not is_finite(radius) or radius <= 0.0 or not is_finite(strength):
		return
	var step := extent * 2.0 / float(segments)
	var min_x := clampi(floori((center.x - radius + extent) / step), 0, segments)
	var max_x := clampi(ceili((center.x + radius + extent) / step), 0, segments)
	var min_z := clampi(floori((center.y - radius + extent) / step), 0, segments)
	var max_z := clampi(ceili((center.y + radius + extent) / step), 0, segments)
	for z in range(min_z, max_z + 1):
		for x in range(min_x, max_x + 1):
			var distance := _vertex(x, z).distance_to(center)
			if distance <= radius:
				var weight := 1.0 - smoothstep(0.0, radius, distance)
				heights[_index(x, z)] += strength * weight

## Carve a shallow basin that meets the placed circular water surface at its
## edge, then blend the bank back into the surrounding terrain.
func shape_lake(center: Vector2, radius: float, water_level: float) -> float:
	var shore_width := maxf(2.0, radius * 0.25)
	var outer := radius + shore_width
	paint_ground(center, outer, true)
	var step := extent * 2.0 / float(segments)
	var min_x := clampi(floori((center.x - outer + extent) / step), 0, segments)
	var max_x := clampi(ceili((center.x + outer + extent) / step), 0, segments)
	var min_z := clampi(floori((center.y - outer + extent) / step), 0, segments)
	var max_z := clampi(ceili((center.y + outer + extent) / step), 0, segments)
	for z in range(min_z, max_z + 1):
		for x in range(min_x, max_x + 1):
			var distance := _vertex(x, z).distance_to(center)
			if distance > outer:
				continue
			var index := _index(x, z)
			if distance <= radius:
				var bank := smoothstep(radius * 0.60, radius, distance)
				heights[index] = lerpf(water_level - 1.25, water_level, bank)
			else:
				var blend := smoothstep(radius, outer, distance)
				heights[index] = lerpf(water_level, heights[index], blend)
			if distance >= radius * 0.75 and distance <= radius + shore_width * 0.5:
				surfaces[index] = 2
				colors[index] = Color.WHITE
	return outer

func paint_surface(center: Vector2, radius: float, surface: int, tint: Color = Color.WHITE) -> void:
	if segments < 1 or radius <= 0.0 or not is_finite(radius) or surface < 0 or surface > 255:
		return
	var step := extent * 2.0 / float(segments)
	var min_x := clampi(floori((center.x - radius + extent) / step), 0, segments)
	var max_x := clampi(ceili((center.x + radius + extent) / step), 0, segments)
	var min_z := clampi(floori((center.y - radius + extent) / step), 0, segments)
	var max_z := clampi(ceili((center.y + radius + extent) / step), 0, segments)
	for z in range(min_z, max_z + 1):
		for x in range(min_x, max_x + 1):
			if _vertex(x, z).distance_squared_to(center) <= radius * radius:
				var index := _index(x, z)
				surfaces[index] = surface
				colors[index] = tint

## Rebuild a bounded tile using the same vertices for rendering and collision.
## A surface ID is selected per cell; material assignment is left to callers.
func build_tile(x0: int, z0: int, width: int, depth: int, materials: Dictionary = {}) -> ArrayMesh:
	if segments < 1 or x0 < 0 or z0 < 0 or width < 1 or depth < 1 or x0 + width > segments or z0 + depth > segments:
		return null
	var step := extent * 2.0 / float(segments)
	var positions := PackedVector3Array()
	var normals := PackedVector3Array()
	var tangents := PackedFloat32Array()
	var vertex_colors := PackedColorArray()
	var uvs := PackedVector2Array()
	for z in range(z0, z0 + depth + 1):
		for x in range(x0, x0 + width + 1):
			var index := _index(x, z)
			var point := _vertex(x, z)
			var normal := Vector3(heights[_index(maxi(x - 1, 0), z)] - heights[_index(mini(x + 1, segments), z)], 2.0 * step, heights[_index(x, maxi(z - 1, 0))] - heights[_index(x, mini(z + 1, segments))]).normalized()
			var tangent := (Vector3.RIGHT - normal * normal.x).normalized()
			positions.append(Vector3(point.x, heights[index], point.y))
			normals.append(normal)
			tangents.append_array([tangent.x, tangent.y, tangent.z, -1.0])
			vertex_colors.append(colors[index])
			uvs.append(point * 0.085)
	var grouped: Dictionary = {}
	for z in depth:
		for x in width:
			if cells[(z0 + z) * segments + x0 + x] == 0:
				continue
			var surface: int = surfaces[_index(x0 + x, z0 + z)]
			if not grouped.has(surface):
				grouped[surface] = PackedInt32Array()
			var a := z * (width + 1) + x
			var indices: PackedInt32Array = grouped[surface]
			indices.append_array([a, a + 1, a + width + 1, a + 1, a + width + 2, a + width + 1])
			grouped[surface] = indices
	var mesh := ArrayMesh.new()
	var keys := grouped.keys()
	keys.sort()
	for surface in keys:
		var arrays: Array = []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = positions
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_TANGENT] = tangents
		arrays[Mesh.ARRAY_COLOR] = vertex_colors
		arrays[Mesh.ARRAY_TEX_UV] = uvs
		arrays[Mesh.ARRAY_INDEX] = grouped[surface]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		if materials.has(surface):
			mesh.surface_set_material(mesh.get_surface_count() - 1, materials[surface])
	return mesh

func to_data() -> Dictionary:
	var rgba: Array[int] = []
	for color: Color in colors:
		rgba.append(color.to_rgba32())
	return {"segments": segments, "extent": extent, "heights": Array(heights), "colors": rgba, "surfaces": Array(surfaces), "cells": Array(cells)}

func from_data(data: Dictionary) -> Error:
	var size := int(data.get("segments", 0))
	var half_extent := float(data.get("extent", 0.0))
	if size < 1 or size > 1024 or not is_finite(half_extent) or half_extent <= 0.0:
		return ERR_INVALID_DATA
	var vertex_count := (size + 1) * (size + 1)
	var raw_heights: Variant = data.get("heights")
	var raw_colors: Variant = data.get("colors")
	var raw_surfaces: Variant = data.get("surfaces")
	var raw_cells: Variant = data.get("cells")
	if not raw_heights is Array or not raw_colors is Array or not raw_surfaces is Array or not raw_cells is Array:
		return ERR_INVALID_DATA
	if raw_heights.size() != vertex_count or raw_colors.size() != vertex_count or raw_surfaces.size() != vertex_count or raw_cells.size() != size * size:
		return ERR_INVALID_DATA
	for value in raw_heights:
		if not (value is float or value is int) or not is_finite(float(value)):
			return ERR_INVALID_DATA
	for value in raw_colors:
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 4294967295.0 or floorf(float(value)) != float(value):
			return ERR_INVALID_DATA
	for value in raw_surfaces:
		if not (value is float or value is int) or not is_finite(float(value)) or float(value) < 0.0 or float(value) > 255.0 or floorf(float(value)) != float(value):
			return ERR_INVALID_DATA
	for value in raw_cells:
		if not (value is float or value is int) or float(value) not in [0.0, 1.0]:
			return ERR_INVALID_DATA
	initialize(size, half_extent, false)
	for index in vertex_count:
		heights[index] = float(raw_heights[index])
		colors[index] = Color.hex(int(raw_colors[index]))
		surfaces[index] = int(raw_surfaces[index])
	for index in cells.size():
		cells[index] = int(raw_cells[index])
	return OK
