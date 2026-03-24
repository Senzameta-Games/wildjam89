extends Node

## Magnetism system — upgradeable player ability.
## pull_range = 0 means disabled. Wire upgrades via set_range() and add_affected_type().

var pull_range: float = 0.0
var affected_types: Array[StringName] = []
var pull_speed: float = 400.0

func set_range(new_range: float) -> void:
	pull_range = new_range

func add_affected_type(group: StringName) -> void:
	if group not in affected_types:
		affected_types.append(group)

func remove_affected_type(group: StringName) -> void:
	affected_types.erase(group)

func is_active() -> bool:
	return pull_range > 0.0 and not affected_types.is_empty()

## Returns all Node2D instances in affected groups within pull_range of from_position.
func get_attracted_nodes(from_position: Vector2) -> Array[Node2D]:
	var result: Array[Node2D] = []
	if not is_active():
		return result
	for group in affected_types:
		for node in get_tree().get_nodes_in_group(group):
			if node is Node2D and node.global_position.distance_to(from_position) <= pull_range:
				result.append(node as Node2D)
	return result
