extends Node2D

# Define the signal
signal grow_tree(amount: int)
signal height_reached(amount: int)

var tree_height: int = 0 : set = _on_tree_height_changed
@onready var tree_trunk = $TreeTrunk
@onready var tree_branches = $TreeBranches

@export var trunk_textures: Array[Texture2D] = []
@export var tree_base_texture: Texture2D
@export var tree_top_texture: Texture2D
@export var trunk_section_height: int = 32  # Changed from hardcoded 16
@export var growth_duration: float = 0.5
@export var reach_height: int = 10

var is_growing: bool = false
var growth_queue: int = 0
var tree_top_sprite: Sprite2D  # Reference to the top sprite

func _ready():
	# Connect the growth signal to our own signal receiver
	grow_tree.connect(_on_grow_tree_signal)
	_setup_tree_base()
	_setup_tree_top()

func _setup_tree_base():
	# Create the base sprite if texture is provided
	if tree_base_texture:
		var base_sprite = Sprite2D.new()
		base_sprite.texture = tree_base_texture
		base_sprite.position.y = 0  # At ground level
		tree_trunk.add_child(base_sprite)
		# Keep base at bottom by moving to index 0
		tree_trunk.move_child(base_sprite, 0)

func _setup_tree_top():
	if tree_top_texture:
		tree_top_sprite = Sprite2D.new()
		tree_top_sprite.texture = tree_top_texture
		tree_top_sprite.position.y = -tree_height * trunk_section_height  # Was * 16
		tree_trunk.add_child(tree_top_sprite)

func _update_tree_top_position():
	if tree_top_sprite:
		tree_top_sprite.position.y = -tree_height * trunk_section_height  # Was * 16

func _input(event):
	if event.is_action_pressed("ui_accept"):  # Spacebar
		grow_tree.emit(1)  # Emit signal to self

func _on_grow_tree_signal(amount: int):
	tree_height += amount

func _on_tree_height_changed(new_value):
	var growth_amount = new_value - tree_height
	tree_height = new_value
	growth_queue += growth_amount
	_try_grow_next()
	
	# Update tree top position
	_update_tree_top_position()
	
	# Check if we've reached the winning height
	if tree_height >= reach_height:
		height_reached.emit(tree_height)

func _try_grow_next():
	if is_growing or growth_queue <= 0:
		return
	
	is_growing = true
	growth_queue -= 1
	_animate_trunk_section()

func _animate_trunk_section():
	var new_section = Sprite2D.new()
	
	if trunk_textures.size() > 0:
		new_section.texture = trunk_textures.pick_random()
	
	# Start position (at current top)
	var start_y = -(tree_height - growth_queue - 1) * trunk_section_height
	# End position (section height higher)  
	var end_y = start_y - trunk_section_height
	
	# Add the missing code here:
	new_section.position.y = start_y
	tree_trunk.add_child(new_section, false)  # Add normally first
	tree_trunk.move_child(new_section, 0)     # Then move to back
	
	# Your tween with proper easing
	var tween = create_tween()
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(new_section, "position:y", end_y, growth_duration)
	
	# Continue growing when this section finishes
	tween.finished.connect(_on_section_grown)

func _on_section_grown():
	is_growing = false
	_try_grow_next()  # Process next in queue
