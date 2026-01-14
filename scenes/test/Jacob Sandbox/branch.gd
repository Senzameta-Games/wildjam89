extends Node2D

@export var branch_sprite: Texture2D
@export var branch_length: int = 24
@export var grow_duration: float = 0.4

@onready var tree_node: SeedTree = get_node("../Tree")
@onready var branches_node = get_node("../TreeBranches")

var growth_count: int = 0
var branch_height: int = 0

func _ready():
	if tree_node:
		tree_node.growth_completed.connect(_on_growth_completed)

func _on_growth_completed():
	growth_count += 1
	# Create a branch every growth cycle
	if growth_count % 1 == 0:
		_spawn_branch_at_next_height()

func _spawn_branch_at_next_height():
	if branch_height >= tree_node.tree_height:
		return
		
	var side = -1 if randf() < 0.5 else 1
	var branch_y = tree_node.global_position.y - (branch_height * tree_node.trunk_section_height)
	var branch_x = tree_node.global_position.x + (side * 32)
	
	_create_branch(Vector2(branch_x, branch_y), side)
	branch_height += 1

func _create_branch(global_pos: Vector2, side: int):
	var segments = randi_range(1, 2)
	var total_width = branch_length * segments
	
	# Setup Branch Container
	var branch = StaticBody2D.new()
	branch.name = "Branch_" + str(growth_count)
	
	branch.collision_layer = 0 
	branch.set_collision_layer_value(6, true)
	
	# Add to scene tree before setting local position
	var parent = branches_node if branches_node else get_parent()
	parent.add_child(branch)
	branch.global_position = global_pos
	
	# Setup One-Way Collision
	var collision = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(total_width, 8)
	collision.shape = shape
	collision.one_way_collision = true
	
	# Offset collision based on side (aligning with sprites)
	collision.position.x = ((total_width / 2.0) - 16) * side
	branch.add_child(collision)
	
	# Add Visuals
	for i in range(segments):
		var sprite = Sprite2D.new()
		sprite.texture = branch_sprite
		sprite.scale.x = side
		sprite.position.x = (branch_length * i * side)
		branch.add_child(sprite)
	
	_animate_branch(branch)

func _animate_branch(branch: Node2D):
	branch.scale = Vector2.ZERO
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(branch, "scale", Vector2.ONE, grow_duration)
