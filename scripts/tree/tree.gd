extends Node2D
class_name SeedTree

signal growth_completed
signal tree_died
signal tree_damaged(amount: float)
signal tree_healed(amount: float)
signal new_section_added

var sudden_death: bool = false

# Settings
@export var trunk_textures: Array[Texture2D] = []
@export var trunk_section_height: int = 16
@export var tree_progress: float = 10.0
@export var base_grow_amount: float = 0.1
@export var max_sections: int = 20

@onready var tree_trunk = $TreeTrunk
@onready var tree_top = $TreeTrunk/TreeTop
@onready var tree_collider = $TreeBase/TreeHitbox/TreeCollider
@onready var impulse_grow_sfx: AudioStreamPlayer2D = $SFX/ImpulseGrow

#just leaf things  
var leaf_tier_target: int = 0
var leaf_tier_current: int = 0
@export var leaf_textures: Array[Texture2D] = []
@export var leaf_spread_x: float = 12.0
@export var leaf_spread_y: float = 6.0

var target_sections: int = 0
var current_sections: int = 0
var growing_section: Sprite2D

var damage_per_hit: float = 5.0


func _ready():
	_update_target_sections()
	_update_leaf_tier_target()
	_build_trunk_immediate()
	impulse_grow_sfx.volume_db = -24.0

	growing_section = Sprite2D.new()
	growing_section.name = "GrowingSection"
	if trunk_textures.size() > 0:
		growing_section.texture = trunk_textures.pick_random()
	tree_trunk.add_child(growing_section)

	
func _process(delta: float) -> void:
	# Passive growth
	var passive_bonus = Game.get_flower_bonus()
	var total_growth_speed = base_grow_amount + passive_bonus
	if not sudden_death:
		add_progress(total_growth_speed * delta)
	
	# Update trunk if needed
	_update_trunk_visual()
	# Update leaves if needed
	_update_leaf_visual()

	#grow the tree frame by frame
	growing_section.scale.y = _get_fractional_growth()
	tree_top.position.y = -trunk_section_height * _get_fractional_growth()


func heal_tree(amount: float):
	print("Incoming Heal: ", amount)
	add_progress(amount)
	

func hurt(amount: float):
	print("Incoming Damage: ", amount)
	if sudden_death:
		Game.game_over_called.emit()
		tree_died.emit()
		return
	subtract_progress(amount)

func add_progress(amount: float):
	tree_progress = clampf(tree_progress + amount, 0.0, 100.0)
	
	if sudden_death and tree_progress > 0.0:
		sudden_death = false
		print("sudden death: ", str(sudden_death))

	_update_target_sections()
	_update_leaf_tier_target()
	
	if tree_progress >= 100.0:
		growth_completed.emit()

func _get_fractional_growth() -> float:
	var full_value = (tree_progress / 100.0) * max_sections
	var whole_part = int(full_value)
	var fractional_part = full_value - whole_part
	return fractional_part

func subtract_progress(amount: float):
	var progress_delta = tree_progress - amount
	if progress_delta <= 0.0:
		tree_progress = 0.0
		if not sudden_death:
			sudden_death = true
			print("sudden death: ", str(sudden_death))
	else: tree_progress = progress_delta
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
	var spread_x_per_tier: float = 2.0
	var spread_y_per_tier: float = 2.0
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
			


func _add_trunk_section_at_root():
	for child in tree_trunk.get_children():
		if child == tree_top:
			continue
		child.position.y -= trunk_section_height

	var section = Sprite2D.new()
	section.position = Vector2.ZERO
	
	if trunk_textures.size() > 0:
		section.texture = trunk_textures.pick_random()

	tree_trunk.add_child(section)

#lerp effect for texture that i made that i did not end up using
#func _animate_section_in(section: Sprite2D):
	#var final_y = section.position.y  
	#section.position.y = final_y + trunk_section_height
	#
	#var tween = create_tween()
	#tween.set_trans(Tween.TRANS_QUAD)
	#tween.set_ease(Tween.EASE_OUT)
	#tween.tween_property(section, "position:y", final_y, 0.3)



func _rebuild_trunk():
	# 1. CLEAR OLD SECTIONS (Keep the essential nodes alive)
	for child in tree_trunk.get_children():
		# We must check the names carefully so we don't delete our Hitbox or Top
		if child.name == "TreeTop" or child.name == "TreeHitbox" or child.name == "GrowingSection":
			continue
		child.queue_free()
	
	for i in range(current_sections):
		var section = Sprite2D.new()
		if trunk_textures.size() > 0:
			section.texture = trunk_textures.pick_random()
		
		section.position.y = (i + 1) * trunk_section_height
		tree_trunk.add_child(section)
		#_animate_section_in(section)
		new_section_added.emit()
	
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
	_update_leaf_tier_target()

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
	impulse_grow_sfx.volume_db = -12.0
	impulse_grow_sfx.play()
	add_progress(1.0)
	tree_healed.emit(1.0)
	await impulse_grow_sfx.finished
	impulse_grow_sfx.volume_db = -24.0
	

func _on_tree_hitbox_area_entered(area: Area2D):
	if area.get_parent() is Enemy:
		area.get_parent().sacrifice()
		hurt(damage_per_hit)
	elif area.get_parent() is Bomb:
		hurt(damage_per_hit * 1.2)
