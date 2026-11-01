extends Node3D
## Fixed authored race model. Imported PBR skin/cloth materials are preserved.
@export var race_model_id := ""
@export var body_size := 2
@export var muscularity := 3

func initialize_body() -> void:
	# New race models have a single authored build, without a human skin-tone
	# shader or a replacement-head neck band. Material fidelity stays in the GLB.
	pass
