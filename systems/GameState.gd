## GameState — Adventure mode persistent progression.
## Single source of truth for grove state, run loot, food inventory, and the
## tree registry. Arcade mode does not read or write this autoload; use
## Economy.gd (transient seed balance) and Session.gd (stage/win state) instead.
##
## Accessed by: GroveManager, RunManager, grove_state.gd, run_state.gd,
##              Saves.write_game(), Saves.write_adventure_run().
extends Node

# -- Game phase --
enum Phase { GROVE, DEFENSE, RUN, MENU }
var current_phase: Phase = Phase.MENU

signal phase_changed(new_phase: Phase, old_phase: Phase)

# -- Persistent resources (survive everything) --
var persistent_seeds: int = 0
var acorn_fragments: int = 0  # rare currency, 3-4 per run

# -- Run-scoped resources (cleared on run end) --
# run_currency: intended as a spendable balance within a single run (e.g. a
# shop between rooms). Distinguished from persistent_seeds, which carries over
# to the grove on run completion. Currently unused — no in-run shop exists yet.
# clear_run_currency() is called by RunManager._complete_run() and again by
# set_phase() when leaving RUN; the double-clear is harmless (idempotent).
var run_currency: int = 0

# -- Tree registry --
# Array of dictionaries, each representing a tree's persistent state.
# Format: { "id": int, "position": Vector2, "progress": float }
var trees: Array[Dictionary] = []
var next_tree_id: int = 0

# -- Defense upgrades --
var defense_upgrades: Dictionary = {}  # upgrade_key -> level (int)

# -- Food system --
# Food has two identity fields:
#   food_category: String — determines buff type (e.g. "fruit", "protein", "seed", "grub")
#   food_name: String — display name (e.g. "Blueberry", "Turkey Leg", "Walnut")
#
# Carried food: items the player picked up in runs but hasn't placed yet.
# Array of dictionaries: { "food_category": String, "food_name": String, "health": float (0.0-1.0) }
# health starts at 1.0 when collected; only degrades when stashed and attacked.
var food_inventory: Array[Dictionary] = []

# Stashed food: items placed in the grove (on branches, on the ground, anywhere).
# Array of dictionaries: {
#   "id": int,
#   "food_category": String,
#   "food_name": String,
#   "health": float (0.0-1.0),
#   "tree_id": int,           # nearest tree for grouping, or -1 if on ground
#   "position": Vector2,      # world position in the grove
# }
# Health represents both remaining value AND remaining buff effectiveness.
# A food at 0.3 health provides 30% of its normal buff.
# When health reaches 0.0, the food is fully eaten and removed.
var stashed_food: Array[Dictionary] = []
var next_food_id: int = 0

# -- Player persistent state --
# Permanent ability unlocks are tracked by Abilities.gd.
# This section holds cross-context player state that GameState manages.
var player_entered_grove: bool = false  # triggers heal-to-full on grove entry

# -- Signals for event-bus pattern --
signal resource_changed(resource_type: String, new_amount: int)
signal ability_permanently_unlocked(ability_key: String)
signal tree_registered(tree_id: int)
signal tree_progress_updated(tree_id: int, new_progress: float)
signal tree_removed(tree_id: int)
signal defense_upgrade_installed(upgrade_key: String, level: int)
signal food_stashed(food_id: int)
signal food_consumed(food_id: int, food_category: String, health: float)
signal food_eaten_by_bugs(food_id: int)
signal food_inventory_changed

# -- Resource API --

func add_resource(type: String, amount: int) -> void:
	match type:
		"seeds":
			persistent_seeds += amount
		"acorn_fragments":
			acorn_fragments += amount
		"run_currency":
			run_currency += amount
		_:
			push_warning("GameState: Unknown resource type '%s'" % type)
			return
	resource_changed.emit(type, get_resource(type))

func spend_resource(type: String, amount: int) -> bool:
	var current = get_resource(type)
	if current < amount:
		return false
	add_resource(type, -amount)
	return true

func get_resource(type: String) -> int:
	match type:
		"seeds": return persistent_seeds
		"acorn_fragments": return acorn_fragments
		"run_currency": return run_currency
		_: return 0

func clear_run_currency() -> void:
	run_currency = 0
	resource_changed.emit("run_currency", 0)

# -- Tree registry API --

func register_tree(position: Vector2, initial_progress: float = 0.0) -> int:
	var id = next_tree_id
	next_tree_id += 1
	trees.append({
		"id": id,
		"position": position,
		"progress": initial_progress,
	})
	tree_registered.emit(id)
	return id

func update_tree_progress(tree_id: int, new_progress: float) -> void:
	for tree in trees:
		if tree["id"] == tree_id:
			tree["progress"] = new_progress
			tree_progress_updated.emit(tree_id, new_progress)
			return

func remove_tree(tree_id: int) -> void:
	for i in range(trees.size()):
		if trees[i]["id"] == tree_id:
			trees.remove_at(i)
			tree_removed.emit(tree_id)
			return

func get_tree_data(tree_id: int) -> Dictionary:
	for tree in trees:
		if tree["id"] == tree_id:
			return tree
	return {}

# -- Phase transitions --

func set_phase(new_phase: Phase) -> void:
	var old = current_phase
	current_phase = new_phase
	phase_changed.emit(new_phase, old)
	if old == Phase.RUN and new_phase != Phase.RUN:
		clear_run_currency()  # may also have been called by RunManager._complete_run(); idempotent

# -- Food inventory API --

## Add food to the player's carried inventory (collected during a run).
func add_food_to_inventory(food_category: String, food_name: String) -> void:
	food_inventory.append({
		"food_category": food_category,
		"food_name": food_name,
		"health": 1.0,
	})
	food_inventory_changed.emit()

## Remove food from carried inventory by index. Returns the food dict, or empty if invalid.
func remove_food_from_inventory(index: int) -> Dictionary:
	if index < 0 or index >= food_inventory.size():
		return {}
	var food = food_inventory[index]
	food_inventory.remove_at(index)
	food_inventory_changed.emit()
	return food

## Place food from inventory into the grove.
## tree_id can be -1 if placed on the ground.
## Returns the stashed food ID, or -1 on failure.
func stash_food(inventory_index: int, tree_id: int, world_position: Vector2) -> int:
	var food = remove_food_from_inventory(inventory_index)
	if food.is_empty():
		return -1
	var id = next_food_id
	next_food_id += 1
	stashed_food.append({
		"id": id,
		"food_category": food["food_category"],
		"food_name": food["food_name"],
		"health": food["health"],
		"tree_id": tree_id,
		"position": world_position,
	})
	food_stashed.emit(id)
	return id

## Player eats a stashed food item (consuming it for a buff before a run).
## Returns the food dict (with current health) for buff calculation, or empty if invalid.
func consume_stashed_food(food_id: int) -> Dictionary:
	for i in range(stashed_food.size()):
		if stashed_food[i]["id"] == food_id:
			var food = stashed_food[i]
			stashed_food.remove_at(i)
			food_consumed.emit(food_id, food["food_category"], food["health"])
			return food
	return {}

## Player eats food directly from inventory (not yet stashed).
## Returns the food dict for buff calculation, or empty if invalid.
func consume_inventory_food(inventory_index: int) -> Dictionary:
	var food = remove_food_from_inventory(inventory_index)
	if food.is_empty():
		return {}
	food_consumed.emit(-1, food["food_category"], food["health"])
	return food

## Called by defense system when a bug deals damage to a stashed food item.
func damage_stashed_food(food_id: int, amount: float) -> void:
	for i in range(stashed_food.size()):
		if stashed_food[i]["id"] == food_id:
			stashed_food[i]["health"] = maxf(stashed_food[i]["health"] - amount, 0.0)
			if stashed_food[i]["health"] <= 0.0:
				stashed_food.remove_at(i)
				food_eaten_by_bugs.emit(food_id)
			return

## Get all stashed food, optionally filtered by tree.
func get_stashed_food(filter_tree_id: int = -2) -> Array[Dictionary]:
	if filter_tree_id == -2:
		return stashed_food
	var result: Array[Dictionary] = []
	for food in stashed_food:
		if food["tree_id"] == filter_tree_id:
			result.append(food)
	return result

# -- Ability unlock (event bus pattern) --

func unlock_ability_permanent(ability_key: String) -> void:
	Abilities.unlock_ability(ability_key)
	ability_permanently_unlocked.emit(ability_key)

# -- Serialization --

func serialize() -> Dictionary:
	return {
		"persistent_seeds": persistent_seeds,
		"acorn_fragments": acorn_fragments,
		"trees": trees.duplicate(true),
		"next_tree_id": next_tree_id,
		"defense_upgrades": defense_upgrades.duplicate(),
		"food_inventory": food_inventory.duplicate(true),
		"stashed_food": stashed_food.duplicate(true),
		"next_food_id": next_food_id,
		"player_entered_grove": player_entered_grove,
	}

func deserialize(data: Dictionary) -> void:
	persistent_seeds = data.get("persistent_seeds", 0)
	acorn_fragments = data.get("acorn_fragments", 0)
	trees = []
	for t in data.get("trees", []):
		trees.append(t)
	next_tree_id = data.get("next_tree_id", 0)
	defense_upgrades = data.get("defense_upgrades", {}).duplicate()
	food_inventory = []
	for f in data.get("food_inventory", []):
		food_inventory.append(f)
	stashed_food = []
	for f in data.get("stashed_food", []):
		stashed_food.append(f)
	next_food_id = data.get("next_food_id", 0)
	player_entered_grove = data.get("player_entered_grove", false)
