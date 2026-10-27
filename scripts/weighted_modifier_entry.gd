@tool
extends Resource
class_name WeightedModifierEntry

@export var modifier: ItemModifierDefinition
## Relative weight, not a fixed percentage. The parent pool normalizes all
## positive weights to a 100% roll distribution automatically.
@export_range(0.0, 10000.0, 0.1, "or_greater") var weight: float = 1.0
