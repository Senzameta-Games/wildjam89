extends Node2D
#imma keep it real i don't really understand how this alien technology works

# Settings
@export var branch_sprite: Texture2D


@export var branch_length: int = 24
@export var grow_duration: float = 0.4

# Navigation: Finding the Tree node
@onready var tree_node: SeedTree = get_node("../Tree")

# The "Registry": A list to keep track of every branch object created
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

	# CASE 1: Tree grew taller
	if current_branch_count < current_trunk_height:
		# 'current_branch_count' is effectively the "Floor Number" we are on.
		# Check if it's divisible by 2
		if current_branch_count % 2 == 0:
			_spawn_branch_at_next_height()
		else:
			# IMPORTANT: Even if we skip spawning a branch, 
			# we add 'null' to the list. 
			# This keeps our "Branch List" the same height as the "Tree Trunk".
			active_branches.append(null)
		
	# CASE 2: Tree shrank
	elif current_branch_count > current_trunk_height:
		_remove_excess_branches()

func _on_growth_completed():
	# Only spawn if we haven't already reached the current height
	if active_branches.size() < tree_node.current_sections:
		_spawn_branch_at_next_height()

func _spawn_branch_at_next_height():
	# Identify which "floor" this branch belongs to
	var branch_index = active_branches.size() 
	
	# MATH: Base Y - (Index * Height)
	# Index 0 sits at the first log, Index 1 at the second, etc.
	var y_offset = branch_index * tree_node.trunk_section_height
	var branch_y = tree_node.global_position.y - y_offset
	var branch_x = tree_node.global_position.x
	
	var side = -1 if randf() < 0.5 else 1
	_create_branch(Vector2(branch_x, branch_y), side)

func _create_branch(global_pos: Vector2, side: int):
	# 1. Randomize the "Blueprint"
	var segments = randi_range(1, 3)
	var total_width = branch_length * segments
	
	var branch = StaticBody2D.new()
	branch.name = "Branch_" + str(active_branches.size())
	
	# Physics setup
	branch.collision_layer = 0
	branch.set_collision_layer_value(6, true)
	
	add_child(branch)
	
	# THE MATH: Move the anchor to the 16px bark edge
	var edge_offset = side * 16 
	branch.global_position = Vector2(global_pos.x + edge_offset, global_pos.y)
	
	active_branches.append(branch)
	
	# 2. THE TILING LOOP
	for i in range(segments):
		var sprite = Sprite2D.new()
		sprite.texture = branch_sprite
		sprite.scale.x = side
		
		# Position Math:
		# If branch_length is 24, the first center is at 12. 
		# The second is at 12 + 24, etc.
		var offset_from_bark = (branch_length * i) + (branch_length / 2.0)
		sprite.position.x = offset_from_bark * side
		branch.add_child(sprite)
	
	# 3. COLLISION
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(total_width, 8) # One box covers all tiles
	collision.shape = shape
	collision.one_way_collision = true
	collision.position.x = (total_width / 2.0) * side
	branch.add_child(collision)
	
	_animate_branch_in(branch)

func _remove_excess_branches():
	# Pop the last (highest) branch out of our list
	var branch_to_remove = active_branches.pop_back()
	
	if is_instance_valid(branch_to_remove):
		# You could add a "Fall away" animation here!
		branch_to_remove.queue_free()

func _add_collision(branch, side):
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(branch_length, 8)
	collision.shape = shape
	collision.one_way_collision = true
	# Offset collision to match the sprite's arm
	collision.position.x = (branch_length / 2.0 + 16) * side
	branch.add_child(collision)

func _animate_branch_in(branch: Node2D):
	branch.scale = Vector2.ZERO
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(branch, "scale", Vector2.ONE, grow_duration)
