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
@export var base_grow_amount: float = 0.5
@export var max_sections: int = 20

@onready var tree_trunk = $TreeTrunk
@onready var tree_top = $TreeTrunk/TreeTop
var target_sections: int = 0
var current_sections: int = 0

func _ready():
	_update_target_sections()
	_build_trunk_immediate()

func _process(delta):
	# Passive growth
	add_progress(base_grow_amount * delta)
	
	# Update trunk if needed
	_update_trunk_visual()


func heal_tree(amount: float):
	print("Incoming Heal: ", amount)
	add_progress(amount)

func damage_tree(amount: float):
	print("Incoming Damage: ", amount)
	subtract_progress(amount)

func add_progress(amount: float):
	tree_progress = clampf(tree_progress + amount, 0.0, 100.0)
	_update_target_sections()
	
	if tree_progress >= 100.0:
		growth_completed.emit()

func subtract_progress(amount: float):
	tree_progress = clampf(tree_progress - amount, 0.0, 100.0)
	_update_target_sections()
	
	if tree_progress <= 0.0:
		tree_died.emit()

func _update_target_sections():
	target_sections = int((tree_progress / 100.0) * max_sections)

func _update_trunk_visual():
	if current_sections != target_sections:
		current_sections = target_sections
		_rebuild_trunk()

func _rebuild_trunk():
	# Clear old sections
	for child in tree_trunk.get_children():
		if child.name == "TreeTop":
			continue
		child.queue_free()
	
	# Add new sections
	for i in range(current_sections):
		var section = Sprite2D.new()
		if trunk_textures.size() > 0:
			section.texture = trunk_textures.pick_random()
		section.position.y = (i + 1) * trunk_section_height
		tree_trunk.add_child(section)
		new_section_added.emit()
	
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
		damage_tree(10)
		print("Manually Hurting: ", tree_progress, "%")

func _on_shop_interacted():
	add_progress(5.0)
