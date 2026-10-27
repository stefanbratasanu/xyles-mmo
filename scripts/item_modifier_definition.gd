@tool
extends Resource
class_name ItemModifierDefinition

## Pure data asset for an equipment modifier. These resources contain no
## executable user-authored code, so modifier catalogs remain safe to edit.
@export var id: StringName = &""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var stat_key: StringName = &""
## Additive delta: +0.08 means an 8% increase when applied to a multiplier stat.
@export var amount: float = 0.0
