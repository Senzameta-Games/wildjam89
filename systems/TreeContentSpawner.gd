class_name TreeContentSpawner
extends Node

@export var seed_scn: PackedScene
@export var enemy_spawner_scn: PackedScene
@export var enemy_roster: Array[PackedScene] = []

## Spawn weight configuration
@export var chance_nothing: float = 0.2
@export var chance_seeds: float = 0.4
@export var chance_passive_spawner: float = 0.15
## Remaining chance = aggro enemy

var _spawned_content: Array[Node] = []

func _ready() -> void:
	# Connect to all current and future trees
	get_tree().node_added.connect(_on_node_added)
	# Connect to existing trees
	for tree in get_tree().get_nodes_in_group("tree"):
		_try_connect_tree(tree)

func _on_node_added(node: Node) -> void:
	if node.is_in_group("tree"):
		_try_connect_tree(node)

func _try_connect_tree(tree: Node) -> void:
	var limb_mgr = tree.get_node_or_null("LimbManager")
	if limb_mgr and limb_mgr is TreeLimbManager:
		if not limb_mgr.limb_spawn_point_available.is_connected(_on_spawn_point):
			limb_mgr.limb_spawn_point_available.connect(_on_spawn_point)
		# Also connect tree death for cleanup
		if tree.has_signal("tree_died") and not tree.tree_died.is_connected(_on_tree_died):
			tree.tree_died.connect(_on_tree_died)

func _on_spawn_point(spawn_global_pos: Vector2, side: int, limb_index: int) -> void:
	if limb_index == 0:
		return  # Don't spawn on ground-level limbs

	var roll := randf()

	if roll < chance_nothing:
		return

	if roll < chance_nothing + chance_seeds:
		_spawn_seeds(spawn_global_pos, side)
		return

	if roll < chance_nothing + chance_seeds + chance_passive_spawner:
		_spawn_passive_spawner(spawn_global_pos, side)
		return

	_spawn_aggro_enemy(spawn_global_pos, side)

func _spawn_seeds(pos: Vector2, side: int) -> void:
	if not seed_scn:
		return
	var seed_node = seed_scn.instantiate()
	get_tree().current_scene.add_child(seed_node)
	seed_node.global_position = pos + Vector2(16 * side, -16)
	if seed_node.has_method("setup_world"):
		seed_node.setup_world(randi_range(5, 15))
	_spawned_content.append(seed_node)

func _spawn_passive_spawner(pos: Vector2, side: int) -> void:
	if not enemy_spawner_scn:
		return
	var spawner = enemy_spawner_scn.instantiate()
	get_tree().current_scene.add_child(spawner)
	spawner.global_position = pos + Vector2(16 * side, -16)
	spawner.spawn_passive = true
	spawner.enemies = enemy_roster
	spawner.timer_interval = randf_range(3.0, 6.0)
	_spawned_content.append(spawner)

func _spawn_aggro_enemy(pos: Vector2, side: int) -> void:
	if enemy_roster.is_empty():
		return
	var enemy_scn = enemy_roster.pick_random()
	var enemy = enemy_scn.instantiate()
	get_tree().current_scene.add_child(enemy)
	enemy.global_position = pos + Vector2(16 * side, -16)
	if enemy.has_method("aggro_player"):
		enemy.call_deferred("aggro_player")
	_spawned_content.append(enemy)

func _on_tree_died() -> void:
	# Clean up content we spawned
	for node in _spawned_content:
		if is_instance_valid(node):
			node.queue_free()
	_spawned_content.clear()

func _process(_delta: float) -> void:
	# Prune freed nodes periodically
	if Engine.get_process_frames() % 60 == 0:
		_spawned_content = _spawned_content.filter(func(n): return is_instance_valid(n))
