extends Node2D

# Settings
@export var branch_sprite: Texture2D
@export var leaf_sprites: Array[Texture2D] = []  # Array of different leaf textures
@export var leaves_per_segment: int = 3  # Average leaves per branch segment
@export var leaf_spread: float = 8.0  # How far leaves can be from branch center
@export var branch_length: int = 24
@export var grow_duration: float = 0.4

@export_category("Spawning")
@export var seed_bundle_scn: PackedScene
@export var enemy_spawner_scn: PackedScene # NEW: Spawner scene reference
@export var enemy_roster: Array[PackedScene] = []

# Spawn Weights
@export var spawn_chance_nothing: float = 0.5
@export var spawn_chance_seeds: float = 0.25


@onready var tree_node: SeedTree = owner

var active_branches: Array[Node2D] = []

func _ready():
	if tree_node:
		# Listen for growth to spawn branches
		tree_node.growth_completed.connect(_on_growth_completed)

func _process(_delta):
	if not tree_node:
		return
	
	var current_trunk_height = tree_node.current_sections
	var current_branch_count = active_branches.size()
	
	# tree grew taller
	if current_branch_count < current_trunk_height:
		# Check if it's divisible by 2
		if current_branch_count % 2 == 0:
			_spawn_branch_at_next_height()
		else:
			active_branches.append(null)
	
	# tree shrank
	elif current_branch_count > current_trunk_height:
		_remove_excess_branches()

func _on_growth_completed():
	# only spawn if we haven't already reached the current height
	if active_branches.size() < tree_node.current_sections:
		_spawn_branch_at_next_height()

func _spawn_branch_at_next_height():
	# get floor this branch belongs to
	var branch_index = active_branches.size()

	var y_offset = branch_index * tree_node.trunk_section_height
	var branch_y = tree_node.global_position.y - y_offset
	var branch_x = tree_node.global_position.x
	var side = -1 if randf() < 0.5 else 1
	
	_create_branch(Vector2(branch_x, branch_y), side)

func _create_branch(global_pos: Vector2, side: int):
	var current_idx = active_branches.size()
	var max_segments = 5
	
	if current_idx <= 2:
		max_segments = 2
		
	var segments = randi_range(1, max_segments)
	var total_width = branch_length * segments

	var branch = StaticBody2D.new()
	branch.name = "Branch_" + str(active_branches.size())

	branch.collision_layer = 0
	branch.set_collision_layer_value(6, true)
	add_child(branch)

	var edge_offset = side * 16
	branch.global_position = Vector2(global_pos.x + edge_offset, global_pos.y)
	active_branches.append(branch)

	var leaf_idx := [0]

	for i in range(segments):
		var sprite = Sprite2D.new()
		sprite.texture = branch_sprite
		sprite.scale.x = side

		var offset_from_bark = (branch_length * i) + (branch_length / 2.0)
		sprite.position.x = offset_from_bark * side
		branch.add_child(sprite)

		_add_leaves_to_segment(branch, i, side, offset_from_bark, leaf_idx)

	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(total_width, 8)
	collision.shape = shape
	collision.one_way_collision = true
	collision.position.x = (total_width / 2.0) * side
	branch.add_child(collision)
	
	_try_spawn_content(branch, side, total_width, current_idx)

	_animate_branch_in(branch)

func _try_spawn_content(branch: Node2D, side: int, total_width: float, branch_index) -> void:
	if branch_index == 0:
		return
		
	var roll = randf()
	
	# 1. Spawn Nothing
	if roll < spawn_chance_nothing:
		return
		
	# Find spawn spot
	var spawn_dist = randf_range(branch_length, total_width - 8)
	var spawn_pos = branch.global_position + Vector2(spawn_dist * side, -16)
	
	# 2. Spawn Seeds
	if roll < (spawn_chance_nothing + spawn_chance_seeds):
		if seed_bundle_scn:
			var bundle = seed_bundle_scn.instantiate()
			get_tree().current_scene.add_child(bundle)
			bundle.global_position = spawn_pos
		return

	# 3. Spawn Enemy Spawner (NEW)
	# Roll check for spawner (approx 10-15%)
	var spawner_threshold = spawn_chance_nothing + spawn_chance_seeds + 0.15 # 0.5 + 0.25 + 0.15 = 0.9
	
	if roll < spawner_threshold and enemy_spawner_scn:
		var spawner = enemy_spawner_scn.instantiate()
		get_tree().current_scene.add_child(spawner)
		spawner.global_position = spawn_pos
		
		# Configure spawner to be passive
		spawner.spawn_passive = true
		spawner.enemies = enemy_roster # Give it the roster
		spawner.timer_interval = randf_range(3.0, 6.0)
		return

	# 4. Aggro Enemy Spawn (Remaining %)
	if not enemy_roster.is_empty():
		var enemy_scn = enemy_roster.pick_random()
		var enemy = enemy_scn.instantiate()
		get_tree().current_scene.add_child(enemy)
		enemy.global_position = spawn_pos
		
		# enemy.gd's _ready() calls aggro_tree() first
		# call aggro_player() instead and wait a frame to do it
		if enemy.has_method("aggro_player"):
			enemy.call_deferred("aggro_player")

func _add_leaves_to_segment(
	branch: Node2D,
	segment_index: int,
	side: int,
	segment_center_x: float,
	leaf_idx: Array
):
	if leaf_sprites.is_empty():
		return

	var leaf_count = randi_range(1, leaves_per_segment)
	if segment_index == 0:
		leaf_count = max(1, leaf_count - 1)

	for i in range(leaf_count):
		var leaf = Sprite2D.new()
		leaf.texture = leaf_sprites[randi() % leaf_sprites.size()]

		var base_x = segment_center_x * side
		var random_x_offset = randf_range(-leaf_spread, leaf_spread)
		var random_y_offset = randf_range(-leaf_spread, leaf_spread)

		leaf.position = Vector2(
			base_x + random_x_offset * side,
			random_y_offset
		)

		leaf.scale = Vector2.ONE * randf_range(0.7, 1.2)
		leaf.rotation = randf_range(-PI / 4, PI / 4)

		if randf() < 0.5:
			leaf.scale.x *= -1

		branch.add_child(leaf)

		# stagger across the whole branch (doesn't reset per segment)
		_animate_leaf_in(leaf, leaf_idx[0] * 0.05)
		leaf_idx[0] += 1

func _animate_leaf_in(leaf: Sprite2D, delay: float = 0.0):
	leaf.modulate.a = 0.0  # Start transparent
	var original_scale = leaf.scale
	leaf.scale = original_scale * 0.3  # Start much smaller
	
	var tween = create_tween()
	tween.tween_interval(delay)
	
	# Fade in
	tween.parallel().tween_property(leaf, "modulate:a", 1.0, 0.3)
	
	# Scale up with bounce
	tween.parallel().tween_property(leaf, "scale", original_scale, 0.4) \
		.set_trans(Tween.TRANS_BACK) \
		.set_ease(Tween.EASE_OUT)

func _remove_excess_branches():
	var branch_to_remove = active_branches.pop_back()
	if is_instance_valid(branch_to_remove):
		branch_to_remove.queue_free()

func _animate_branch_in(branch: Node2D):
	branch.scale = Vector2.ZERO
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(branch, "scale", Vector2.ONE, grow_duration)
	if owner and owner.impulse_grow_sfx:
		owner.impulse_grow_sfx.play()
