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
	player_entered_grove = data.get("player_entered_grove", false)
