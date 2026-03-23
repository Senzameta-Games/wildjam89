class_name GroveTreePlacer
extends Node2D
## Provides ordered planting positions for grove trees.
## Returns the next unoccupied slot. Replace internals with dynamic logic
## if needed; GroveManager.plant_new_tree() API stays stable either way.

const POSITION_TOLERANCE: float = 16.0

@export var tree_positions: Array[Vector2] = [
	Vector2(160.0, 288.0),
	Vector2(320.0, 288.0),
	Vector2(480.0, 288.0),
	Vector2(240.0, 288.0),
	Vector2(400.0, 288.0),
]

## Returns the next unoccupied position, or Vector2.INF if all slots are full.
func get_next_position() -> Vector2:
	var occupied: Array[Vector2] = []
	for tree_data: Dictionary in GameState.trees:
		occupied.append(tree_data["position"])
	for pos: Vector2 in tree_positions:
		var taken: bool = false
		for occ: Vector2 in occupied:
			if occ.distance_to(pos) < POSITION_TOLERANCE:
				taken = true
				break
		if not taken:
			return pos
	return Vector2.INF
