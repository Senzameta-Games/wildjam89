extends Node2D
class_name SeedTree

signal growth_completed
signal tree_died
signal tree_damaged(amount: float)
signal tree_healed(amount: float)
signal new_section_added
signal slot_freed(slot_index: int) 

var reward_spawned: bool = false
var sudden_death: bool = false
var slot_index: int = -1

# Settings
@export var trunk_textures: Array[Texture2D] = []
@export var trunk_section_height: int = 16
@export var tree_progress: float = 10.0
@export var max_sections: int = 20

# Growth balancing
const BASE_PASSIVE_GROWTH: float = 0.02
const MAX_PASSIVE_GROWTH: float = 0.08
const ACTIVE_GROWTH_AMOUNT: float = 1.5

@onready var tree_trunk = $TreeTrunk
@onready var tree_top = $TreeTrunk/TreeTop
@onready var tree_collider = $TreeBase/TreeHitbox/TreeCollider
@onready var impulse_grow_sfx: AudioStreamPlayer2D = $SFX/ImpulseGrow

# Leaves
var leaf_tier_target: int = 0
var leaf_tier_current: int = 0
@export var leaf_textures: Array[Texture2D] = []
@export var leaf_spread_x: float = 12.0
@export var leaf_spread_y: float = 6.0

var target_sections: int = 0
var current_sections: int = 0
var growing_section: Sprite2D

var damage_per_hit: float = 2.0

func _ready():
	_update_target_sections()
	_update_leaf_tier_target()
	
	# Create a unique shape for this tree's collider (avoid shared resource issue)
	if tree_collider and tree_collider.shape:
		tree_collider.shape = tree_collider.shape.duplicate()
	
	_build_trunk_immediate()
	impulse_grow_sfx.volume_db = -24.0

	growing_section = Sprite2D.new()
	growing_section.name = "GrowingSection"
	if trunk_textures.size() > 0:
		growing_section.texture = trunk_textures.pick_random()
	tree_trunk.add_child(growing_section)
	
	var shop = find_child("Shop")
	if shop and shop.has_signal("shop_interacted"):
		if not shop.shop_interacted.is_connected(_on_shop_interacted):
			shop.shop_interacted.connect(_on_shop_interacted)

func _process(delta: float) -> void:
	var passive_growth = BASE_PASSIVE_GROWTH
	
	var flower_bonus = Game.get_flower_growth_bonus()
	var active_trees = get_tree().get_nodes_in_group("tree").size()
	
	if active_trees > 0:
		flower_bonus = flower_bonus / float(active_trees)
	
	passive_growth += flower_bonus
	passive_growth = min(passive_growth, MAX_PASSIVE_GROWTH)

	if not sudden_death and tree_progress < 100.0:
		add_progress(passive_growth * delta)
	
	_update_trunk_visual()
	_update_leaf_visual()

	growing_section.scale.y = _get_fractional_growth()
	tree_top.position.y = -trunk_section_height * _get_fractional_growth()

func heal_tree(amount: float):
	add_progress(amount)

func hurt(amount: float):
	# blue flowers
	var defense_multiplier = Game.get_flower_defense_bonus()
	var actual_damage = amount * defense_multiplier
	
	subtract_progress(actual_damage)

func add_progress(amount: float):
	# Cap visual progress at 100
	tree_progress = clampf(tree_progress + amount, 0.0, 100.0)
	
	if sudden_death and tree_progress > 0.0:
		sudden_death = false
	
	_update_target_sections()
	_update_leaf_tier_target()
	
	if tree_progress >= 100.0 and not reward_spawned:
		reward_spawned = true
		growth_completed.emit()

func subtract_progress(amount: float):
	var progress_delta = tree_progress - amount
	
	if progress_delta <= 0.0:
		tree_progress = 0.0
		
		var trees = get_tree().get_nodes_in_group("tree")
		var active_tree_count = 0
		for t in trees:
			if t is SeedTree:
				active_tree_count += 1
		
		if active_tree_count > 1:
			_die_permanently()
		else:
			if not sudden_death:
				sudden_death = true
			else:
				Game.game_over_called.emit()
				tree_died.emit()
	else: 
		tree_progress = progress_delta
		
	tree_progress = clampf(tree_progress, 0.0, 100.0)
	_update_target_sections()
	_update_leaf_tier_target()

func _die_permanently():
	print("Tree died, freeing slot: ", slot_index)
	slot_freed.emit(slot_index)
	
	tree_died.emit()
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

func _get_fractional_growth() -> float:
	var full_value = (tree_progress / 100.0) * max_sections
	var whole_part = int(full_value)
	var fractional_part = full_value - whole_part
	return fractional_part

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
		leaf.position = Vector2(randf_range(-spread_x, spread_x), randf_range(-spread_y, spread_y))
		leaf.z_index = 3
		if leaf_textures.size() > 0:
			leaf.texture = leaf_textures.pick_random()

func _rebuild_trunk():
	for child in tree_trunk.get_children():
		if child.name == "TreeTop" or child.name == "TreeHitbox" or child.name == "GrowingSection":
			continue
		child.queue_free()
	for i in range(current_sections):
		var section = Sprite2D.new()
		if trunk_textures.size() > 0:
			section.texture = trunk_textures.pick_random()
		section.position.y = (i + 1) * trunk_section_height
		tree_trunk.add_child(section)
		new_section_added.emit()
	if tree_collider and tree_collider.shape is RectangleShape2D:
		var total_height = current_sections * trunk_section_height
		var min_buffer: float = 10.0
		
		# Ensure minimum collider height
		if total_height < min_buffer:
			total_height = min_buffer
		
		var shape = tree_collider.shape as RectangleShape2D
		shape.size = Vector2(32, total_height)
		tree_collider.position.y = -(total_height / 2.0) + 10
	tree_trunk.position.y = -current_sections * trunk_section_height
	tree_top.position.y = 0

func _build_trunk_immediate():
	current_sections = target_sections
	_rebuild_trunk()

func _on_shop_interacted():
	# Active growth from depositing seeds
	add_progress(ACTIVE_GROWTH_AMOUNT)
	tree_healed.emit(ACTIVE_GROWTH_AMOUNT)

func _on_tree_hitbox_area_entered(area: Area2D):
	var entity = area.get_parent()
	
	if entity is Bird:
		return

	if entity is Enemy:
		entity.sacrifice()
		hurt(damage_per_hit)

	elif entity is Bomb:
		hurt(damage_per_hit * 1.2)
