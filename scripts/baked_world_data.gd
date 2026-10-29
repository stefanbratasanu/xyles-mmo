extends Resource
## Offline-authored map data. Rebuilt by scripts/dev/bake_world.gd.
@export var format_version: int = 7
@export var playable_bounds: float
@export var terrain_extent: float
@export var terrain_segments: int
@export var static_scene: PackedScene
@export var terrain_heights: PackedFloat32Array
@export var terrain_colors: PackedColorArray
@export var terrain_grid_size: int
@export var sites: Array[Dictionary]
@export var ponds: Array[Dictionary]
@export var roads: Array[PackedVector2Array]
@export var road_cells: Dictionary
@export var road_lamps: Array[Vector3]
@export var tree_points: Array[Vector2]
@export var tree_spacing_cells: Dictionary
@export var grass_points: PackedVector2Array
@export var vegetation_paths: Dictionary
@export var vegetation_counts: Dictionary
@export var terrain_tiles: Dictionary
@export var static_paths: Dictionary
@export var map_image: Image
