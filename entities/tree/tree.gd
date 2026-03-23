extends Node2D
class_name SeedTree

# -- Lifecycle signals --
signal growth_changed(new_progress: float, old_progress: float)
signal threshold_crossed(progress: float, direction: int)  # direction: +1 or -1
signal growth_completed
signal tree_died
signal tree_damaged(amount: float)
signal tree_healed(amount: float)
signal slot_freed(slot_index: int)

# -- Data-driven config --
@export var data: TreeData

# -- Convenience accessors (read from resource, fall back to defaults) --
var max_sections: int:
	get: return data.max_sections if data else 20
var trunk_section_height: int:
	get: return data.trunk_section_height if data else 16
var base_passive_growth: float:
	get: return data.base_passive_growth if data else 0.08
var max_passive_growth: float:
	get: return data.max_passive_growth if data else 2.0
var active_growth_amount: float:
	get: return data.active_growth_amount if data else 0.75

# TODO: Threshold interval should come from TreeGrowthModel or TreeData
const BRANCH_INTERVAL: float = 10.0  # Branch spawns every 10% growth

# -- Runtime state --
var tree_progress: float = 10.0
var reward_spawned: bool = false
var sudden_death: bool = false
var slot_index: int = -1
var damage_per_hit: float = 2.0

# -- Growth model, cached state, and limb manager --
# _growth_model is created in _enter_tree() so it exists before any child's _ready() fires.
var _growth_model: TreeGrowthModel
var _cached_state: Dictionary = {}
@onready var limb_manager: TreeLimbManager = $LimbManager

# target_sections is derived from the cached growth state; no separate tracking needed.
var target_sections: int:
	get: return _cached_state.get("section_count", 0)

func _enter_tree() -> void:
	if data and not _growth_model:
		_growth_model = TreeGrowthModel.new(data)

func _ready() -> void:
	_update_state()
	var shop = find_child("Shop")
	if shop and shop.has_signal("shop_interacted"):
		if not shop.shop_interacted.is_connected(_on_shop_interacted):
			shop.shop_interacted.connect(_on_shop_interacted)
	if _growth_model:
		limb_manager.sync_to_state(_cached_state.limb_states)

func _process(delta: float) -> void:
	if sudden_death or tree_progress >= 100.0:
		return
	var passive_growth = base_passive_growth
	var flower_bonus = FlowerManager.get_flower_growth_bonus()
	var active_trees = get_tree().get_nodes_in_group("tree").size()
	if active_trees > 0:
		flower_bonus /= float(active_trees)
	passive_growth = minf(passive_growth + flower_bonus, max_passive_growth)
	add_progress(passive_growth * delta)

# -- Growth API --

func add_progress(amount: float) -> void:
	var old_progress = tree_progress
	tree_progress = clampf(tree_progress + amount, 0.0, 100.0)
	if sudden_death and tree_progress > 0.0:
		sudden_death = false
	_update_state()
	_emit_threshold_signals(old_progress, tree_progress, 1)
	growth_changed.emit(tree_progress, old_progress)
	if _growth_model:
		limb_manager.sync_to_state(_cached_state.limb_states)
	if tree_progress >= 100.0 and not reward_spawned:
		reward_spawned = true
		growth_completed.emit()

func subtract_progress(amount: float) -> void:
	var old_progress = tree_progress
	tree_progress = clampf(tree_progress - amount, 0.0, 100.0)
	_update_state()
	_emit_threshold_signals(old_progress, tree_progress, -1)
	growth_changed.emit(tree_progress, old_progress)
	if _growth_model:
		limb_manager.sync_to_state(_cached_state.limb_states)
	tree_damaged.emit(amount)
	if tree_progress <= 0.0:
		_handle_death()

func set_progress(value: float) -> void:
	tree_progress = clampf(value, 0.0, 100.0)
	_update_state()
	if _growth_model:
		limb_manager.sync_to_state(_cached_state.limb_states)

func heal_tree(amount: float) -> void:
	add_progress(amount)

func hurt(amount: float) -> void:
	var defense = FlowerManager.get_flower_defense_bonus()
	subtract_progress(amount * defense)

# -- Death --

func _handle_death() -> void:
	var trees = get_tree().get_nodes_in_group("tree")
	var active_count = 0
	for t in trees:
		if t is SeedTree:
			active_count += 1
	if active_count > 1:
		_die_permanently()
	else:
		if not sudden_death:
			sudden_death = true
		else:
			limb_manager.clear_all_limbs()
			Session.game_over_called.emit()
			tree_died.emit()

func _die_permanently() -> void:
	slot_freed.emit(slot_index)
	limb_manager.clear_all_limbs()
	tree_died.emit()
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_callback(queue_free)

# -- Internal --

func _update_state() -> void:
	if _growth_model:
		_cached_state = _growth_model.compute_state(tree_progress)

func _emit_threshold_signals(old_pct: float, new_pct: float, direction: int) -> void:
	var old_bucket = int(old_pct / BRANCH_INTERVAL)
	var new_bucket = int(new_pct / BRANCH_INTERVAL)
	if new_bucket != old_bucket:
		threshold_crossed.emit(new_pct, direction)

# -- Interaction --

func _on_shop_interacted() -> void:
	if tree_progress >= 100.0:
		return
	add_progress(active_growth_amount)
	tree_healed.emit(active_growth_amount)

func _on_tree_hitbox_area_entered(area: Area2D) -> void:
	var entity = area.get_parent()
	if entity is Bird:
		return
	if entity is Enemy:
		entity.sacrifice()
		hurt(damage_per_hit)
	elif entity is Bomb:
		hurt(damage_per_hit * 1.2)

# -- Serialization --

func serialize() -> Dictionary:
	# Structural state (sections, limbs) is NOT saved — it's derived from
	# tree_progress via TreeGrowthModel on load.
	return {
		"slot_index": slot_index,
		"position_x": global_position.x,
		"position_y": global_position.y,
		"tree_progress": tree_progress,
		"reward_spawned": reward_spawned,
		"sudden_death": sudden_death,
	}

func deserialize(data_dict: Dictionary) -> void:
	slot_index = data_dict.get("slot_index", -1)
	global_position = Vector2(
		data_dict.get("position_x", 0.0),
		data_dict.get("position_y", 0.0)
	)
	tree_progress = data_dict.get("tree_progress", 10.0)
	reward_spawned = data_dict.get("reward_spawned", false)
	sudden_death = data_dict.get("sudden_death", false)
	_update_state()
	if _growth_model:
		limb_manager.sync_to_state(_cached_state.limb_states)
