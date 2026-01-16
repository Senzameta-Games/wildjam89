extends Node2D
class_name SeedTree

signal growth_completed
signal tree_died
signal tree_damaged(amount: float)
signal tree_healed(amount: float)
signal new_section_added

# Settings
@export var trunk_textures: Array[Texture2D] = []
@export var trunk_section_height: int = 16
@export var tree_progress: float = 10.0
@export var base_grow_amount: float = 0.1
@export var max_sections: int = 20

@onready var tree_trunk = $TreeTrunk
@onready var tree_top = $TreeTrunk/TreeTop
@onready var tree_collider = $TreeBase/TreeHitbox/TreeCollider



var target_sections: int = 0
var current_sections: int = 0

#just leaf things  
var leaf_tier_target: int = 0
var leaf_tier_current: int = 0
@export var leaf_textures: Array[Texture2D] = []
@export var leaf_spread_x: float = 12.0
@export var leaf_spread_y: float = 6.0




func _ready():
	_update_target_sections()
	_build_trunk_immediate()
	
func _process(delta):
	# Passive growth
	add_progress(base_grow_amount * delta)
	
	# Update trunk if needed
	_update_trunk_visual()
	_update_leaf_visual()

func heal_tree(amount: float):
	print("Incoming Heal: ", amount)
	add_progress(amount)

func hurt(amount: float):
	print("Incoming Damage: ", amount)
	subtract_progress(amount)

func add_progress(amount: float):
	tree_progress = clampf(tree_progress + amount, 0.0, 100.0)
	_update_target_sections()
	_update_leaf_tier_target()
	
	
	if tree_progress >= 100.0:
		growth_completed.emit()

func subtract_progress(amount: float):
	tree_progress = clampf(tree_progress - amount, 0.0, 100.0)
	_update_target_sections()
	_update_leaf_tier_target()

	
	if tree_progress <= 0.0:
		tree_died.emit()

func _update_target_sections():
	target_sections = int((tree_progress / 100.0) * max_sections)
	
func _update_leaf_tier_target():
	leaf_tier_target = int(tree_progress / 10.0)


func _update_leaf_visual():
	if leaf_tier_current != leaf_tier_target:
		leaf_tier_current = leaf_tier_target
		_rebuild_leaves()

func _update_trunk_visual():
	if current_sections != target_sections:
		current_sections = target_sections
		_rebuild_trunk()


func _rebuild_leaves():
	for child in tree_top.get_children():
		child.queue_free()

#spread variables - how spread out are we at the start / how much do we mult each tier
	var leaves_per_tier: int = 10
	var leaf_count: int = (leaves_per_tier * leaf_tier_current)
	var initial_spread_x: float = 12.0
	var initial_spread_y: float = 6.0
	var spread_x_per_tier: float = 3.0
	var spread_y_per_tier: float = 3.0
	var spread_x: float = initial_spread_x + leaf_tier_current * spread_x_per_tier
	var spread_y: float = initial_spread_y + leaf_tier_current * spread_y_per_tier

	
	for i in range(leaf_count):
		var leaf = Sprite2D.new()
		tree_top.add_child(leaf)
		leaf.position = Vector2(
			randf_range(-spread_x, spread_x),
			randf_range(-spread_y, spread_y)
		)
		leaf.z_index = 3
		if leaf_textures.size() > 0:
			leaf.texture = leaf_textures.pick_random()
			

func _rebuild_trunk():
	# 1. CLEAR OLD SECTIONS (Keep the essential nodes alive)
	for child in tree_trunk.get_children():
		# We must check the names carefully so we don't delete our Hitbox or Top
		if child.name == "TreeTop" or child.name == "TreeHitbox":
			continue
		child.queue_free()

	for i in range(current_sections):
		var section = Sprite2D.new()
		if trunk_textures.size() > 0:
			section.texture = trunk_textures.pick_random()
		
		# Position logs from bottom to top
		section.z_index = (10)
		section.position.y = (i + 1) * trunk_section_height
		tree_trunk.add_child(section)
		new_section_added.emit()
	
	# 3. UPDATE COLLIDER (The "Perfect Fit" Logic)
	if tree_collider and tree_collider.shape is RectangleShape2D:
		var total_height = current_sections * trunk_section_height
		var shape = tree_collider.shape as RectangleShape2D
		var min_buffer: float = 10.0
		# Set the box size to exactly the tree's height
		# Using a width of 32, but you can adjust as needed
		shape.size = Vector2(32, total_height)
		if shape.size.y == 0.0:
			total_height += min_buffer
		# Move the collider UP by half its height. 
		# This offsets Godot's center-scaling so the bottom stays at y=0.
		tree_collider.position.y = -(total_height / 2.0) + 10 #added + 10 here to catch snails

	# 4. REPOSITION ENTIRE TRUNK CONTAINER
	# This keeps the base of the tree at the SeedTree's global position
	tree_trunk.position.y = -current_sections * trunk_section_height
	tree_top.position.y = 0

func _build_trunk_immediate():
	current_sections = target_sections
	_rebuild_trunk()
	
func get_progress_percentage() -> float:
	return tree_progress

func set_progress(new_progress: float):
	tree_progress = clampf(new_progress, 0.0, 100.0)
	_update_target_sections()

func _unhandled_input(event: InputEvent):
	# DEBUG: Press 'P' to Grow
	if event.is_action_pressed("DebugTreeGrow"):
		heal_tree(10)
		# We add enough to cross a whole number (e.g., 10%)
		print("Manually Growing: ", tree_progress, "%")

	# DEBUG: Press 'O' to Hurt
	if event.is_action_pressed("DebugTreeHurt"):
		hurt(10)
		print("Manually Hurting: ", tree_progress, "%")

func _on_shop_interacted():
	add_progress(5.0)

func _on_tree_hitbox_area_entered(area: Area2D):
	if area.get_parent() is Enemy:
		area.get_parent().sacrifice()
		subtract_progress(5)
	elif area.get_parent() is Bomb:
		subtract_progress(5)
