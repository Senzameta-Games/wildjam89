extends Node2D

signal growth_started()
signal growth_completed()

@export var trunk_textures: Array[Texture2D] = []
@export var trunk_section_height: int = 32
@export var growth_duration: float = 0.5

@onready var tree_trunk = $TreeTrunk

var tree_height: int = 0
var is_growing: bool = false

func _on_grow_tree_signal(amount: int, _current_height: int):
	if not is_growing:
		tree_height += amount
		_grow_new_section()

func _grow_new_section():
	is_growing = true
	growth_started.emit()
	
	# Create and place new sprite
	var new_section = Sprite2D.new()
	if not trunk_textures.is_empty():
		new_section.texture = trunk_textures.pick_random()
	
	new_section.position.y = tree_height * trunk_section_height
	tree_trunk.add_child(new_section)
	tree_trunk.move_child(new_section, 0)
	
	_animate_growth()

func _animate_growth():
	var step_size = 2
	var total_steps = trunk_section_height / step_size
	var step_delay = growth_duration / total_steps
	
	#  step animation
	for i in range(total_steps):
		tree_trunk.position.y -= step_size
		await get_tree().create_timer(step_delay).timeout
	
	# Overshoot/Bounce effect
	var target_y = tree_trunk.position.y
	var tween = create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	
	tween.tween_property(tree_trunk, "position:y", target_y - 4, 0.18)
	tween.tween_property(tree_trunk, "position:y", target_y, 0.12)
	
	await tween.finished
	is_growing = false
	growth_completed.emit()
