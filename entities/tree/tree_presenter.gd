extends Node2D
class_name TreePresenter

## Observes a SeedTree's growth signals and manages all visual nodes.
## Handles trunk sections, leaf canopy, tree top, collider sizing, and sfx.
## Uses incremental add/remove instead of destructive rebuild.

# -- Visual assets (set in editor on the tree.tscn scene) --
@export var trunk_textures: Array[Texture2D] = []
@export var leaf_textures: Array[Texture2D] = []

# -- Configuration --
var trunk_section_height: int:
	get: return _tree.trunk_section_height if _tree else 16
@export var leaves_per_tier: int = 10
@export var leaf_spread_base: float = 12.0
@export var leaf_spread_per_tier: float = 2.0

# -- Node references (children of the tree scene, found on ready) --
var _tree: SeedTree
var _trunk_node: Node2D
var _tree_top: Area2D
var _tree_collider: CollisionShape2D
var _impulse_grow_sfx: AudioStreamPlayer2D

# -- Growth model --
var _growth_model: TreeGrowthModel

# -- Tracked visual state --
var _trunk_sections: Array[Sprite2D] = []
var _leaf_sprites: Array[Sprite2D] = []
var _current_section_count: int = 0
var _current_leaf_tier: int = 0
var _growing_section: Sprite2D

func _ready() -> void:
	_tree = owner as SeedTree
	if not _tree:
		push_error("TreePresenter: owner is not a SeedTree")
		return

	_trunk_node = _tree.get_node("TreeTrunk")
	_tree_top = _trunk_node.get_node("TreeTop")
	_tree_collider = _tree.get_node("TreeBase/TreeHitbox/TreeCollider")
	_impulse_grow_sfx = _tree.get_node("SFX/ImpulseGrow")

	# Duplicate the collider shape so instances don't share it
	if _tree_collider and _tree_collider.shape:
		_tree_collider.shape = _tree_collider.shape.duplicate()

	_impulse_grow_sfx.volume_db = -24.0

	# Create the fractional growing section
	_growing_section = Sprite2D.new()
	_growing_section.name = "GrowingSection"
	if trunk_textures.size() > 0:
		_growing_section.texture = trunk_textures.pick_random()
	_trunk_node.add_child(_growing_section)

	# Share the tree's growth model — SeedTree creates it in _enter_tree(),
	# which fires before any child _ready(), so it's guaranteed non-null here.
	_growth_model = _tree._growth_model
	if not _growth_model:
		push_error("TreePresenter: SeedTree._growth_model is null — check TreeData is assigned")
		return

	# Connect to tree signals
	_tree.growth_changed.connect(_on_growth_changed)

	# Build initial visual state to match current progress
	_sync_to_current_progress()

func _process(_delta: float) -> void:
	if not _tree or not _growth_model:
		return
	# Smooth the fractional section (the partial section being "grown")
	var full_value = (_tree.tree_progress / 100.0) * _growth_model.data.max_sections
	var fractional = full_value - int(full_value)
	_growing_section.scale.y = fractional
	_tree_top.position.y = -trunk_section_height * fractional

func _on_growth_changed(new_progress: float, _old_progress: float) -> void:
	var state := _growth_model.compute_state(new_progress)
	_sync_trunk(state.section_count)
	_sync_leaves(state.leaf_tier)
	_sync_collider(state.section_count)
	_sync_trunk_position(state.section_count)

# -- Incremental trunk management --

func _sync_trunk(target: int) -> void:
	# Add sections
	while _current_section_count < target:
		var section = Sprite2D.new()
		if trunk_textures.size() > 0:
			section.texture = trunk_textures.pick_random()
		section.position.y = (_current_section_count + 1) * trunk_section_height
		_trunk_node.add_child(section)
		_trunk_sections.append(section)
		_current_section_count += 1

	# Remove sections
	while _current_section_count > target:
		if _trunk_sections.size() > 0:
			var removed = _trunk_sections.pop_back()
			removed.queue_free()
		_current_section_count -= 1

func _sync_trunk_position(section_count: int) -> void:
	_trunk_node.position.y = -section_count * trunk_section_height
	_tree_top.position.y = 0

func _sync_collider(section_count: int) -> void:
	if not _tree_collider or not _tree_collider.shape is RectangleShape2D:
		return
	var total_height = maxf(section_count * trunk_section_height, 10.0)
	var shape = _tree_collider.shape as RectangleShape2D
	shape.size = Vector2(32, total_height)
	_tree_collider.position.y = -(total_height / 2.0) + 10

# -- Incremental leaf management --

func _sync_leaves(target_tier: int) -> void:
	if target_tier == _current_leaf_tier:
		return

	# Clear all leaves and rebuild for new tier.
	# Leaves are random positions, so a full tier swap on 10% boundaries
	# is cleaner than incremental add/remove (which would look discontinuous).
	for leaf in _leaf_sprites:
		if is_instance_valid(leaf):
			leaf.queue_free()
	_leaf_sprites.clear()

	_current_leaf_tier = target_tier
	var leaf_count = leaves_per_tier * _current_leaf_tier
	var spread_x = leaf_spread_base + _current_leaf_tier * leaf_spread_per_tier
	var spread_y = leaf_spread_base + _current_leaf_tier * leaf_spread_per_tier

	for i in range(leaf_count):
		var leaf = Sprite2D.new()
		leaf.z_index = 3
		if leaf_textures.size() > 0:
			leaf.texture = leaf_textures.pick_random()
		leaf.position = Vector2(randf_range(-spread_x, spread_x), randf_range(-spread_y, spread_y))
		_tree_top.add_child(leaf)
		_leaf_sprites.append(leaf)

# -- Initial sync (used on ready and after deserialization) --

func _sync_to_current_progress() -> void:
	var state := _growth_model.compute_state(_tree.tree_progress)
	_sync_trunk(state.section_count)
	_sync_leaves(state.leaf_tier)
	_sync_collider(state.section_count)
	_sync_trunk_position(state.section_count)
