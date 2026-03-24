class_name RunManager
extends Node2D
## Manages a single run session: room sequencing, loot tracking, and
## the return-to-grove handoff. Food is added to GameState immediately
## on pickup; seeds and fragments transfer on run completion.
##
## Save lifecycle:
##   Run start  → delete stale save, write fresh adventure_run save (auto)
##   F5         → write_adventure_run (manual checkpoint)
##   F6         → restore from last adventure_run save
##   Run end    → delete adventure_run save, write game save (handoff to grove)

signal run_completed(loot: Dictionary)

@export var room_sequence: Array[PackedScene] = []
## Door name in the first room whose EnterSpawn the player arrives at
## when starting a run from the grove (typically the left-side door).
@export var initial_entry_door: String = "To_Grove"

var _current_room_index: int = -1
var _current_room: Node2D = null
var _transitioning: bool = false
var _run_seeds: int = 0
var _run_fragments: int = 0
var _run_food: Array[Dictionary] = []   ## {category, name} pairs collected this run
var _run_abilities: Array[String] = []

@onready var room_container: Node2D = $RoomContainer
@onready var _player: Player = $Player
@onready var _pause_menu: CanvasLayer = $RunPause

func _ready() -> void:
	GameState.set_phase(GameState.Phase.RUN)
	Saves.delete_adventure_run_save()
	advance_room(initial_entry_door)
	# Write the initial run save after the room and player position are both
	# settled (both use call_deferred, so this runs after them in queue order).
	_write_save.call_deferred()
	_pause_menu.abandon_run_requested.connect(return_to_grove)
	_pause_menu.return_to_title_requested.connect(_on_exit_to_title)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		_write_save()
	elif event.is_action_pressed("quick_load"):
		var data := Saves.load_adventure_run()
		if not data.is_empty():
			_restore_from_save(data)
			Saves.save_toast.emit("Loaded")

## -- Room loading --

func advance_room(entry_door_name: String = "") -> void:
	_current_room_index += 1
	if _current_room_index >= room_sequence.size():
		_complete_run()
		return
	_load_room(room_sequence[_current_room_index], entry_door_name)

func _load_room(room_scene: PackedScene, entry_door_name: String = "") -> void:
	_transitioning = false
	if _current_room != null and is_instance_valid(_current_room):
		_current_room.queue_free()
	_current_room = room_scene.instantiate() as Node2D
	# Connect signals before the node enters the tree — valid in Godot 4.
	if _current_room.has_signal("room_cleared"):
		_current_room.room_cleared.connect(advance_room)
	if _current_room.has_signal("room_exit_requested"):
		_current_room.room_exit_requested.connect(_on_room_exit_requested)
	# Defer add_child: avoids "can't change monitoring state while flushing"
	# when _load_room is triggered from a body_entered physics callback.
	room_container.call_deferred("add_child", _current_room)
	# Position the player at the entry door after the room is in the tree.
	if not entry_door_name.is_empty():
		_apply_entry_spawn.call_deferred(entry_door_name)

## Move the player to the named door's EnterSpawn global position.
## Called deferred so the room is guaranteed to be in the scene tree.
func _apply_entry_spawn(entry_door_name: String) -> void:
	if _current_room == null or not is_instance_valid(_current_room):
		return
	var doors: Node = _current_room.get_node_or_null("Doors")
	if doors == null:
		return
	var door: Node = doors.get_node_or_null(entry_door_name)
	if door == null:
		push_warning("RunManager: entry door '%s' not found in room" % entry_door_name)
		return
	var enter_spawn := door.get_node_or_null("EnterSpawn") as Marker2D
	if enter_spawn == null:
		push_warning("RunManager: door '%s' has no EnterSpawn child" % entry_door_name)
		return
	# Suppress the body_entered that fires when the player is placed inside this area.
	if door.has_method("suppress_next_entry"):
		door.suppress_next_entry()
	_player.global_position = enter_spawn.global_position

func _on_room_exit_requested(entry_door_name: String, to_grove: bool) -> void:
	if _transitioning:
		return
	_transitioning = true
	if to_grove:
		return_to_grove()
	else:
		advance_room(entry_door_name)

## -- Loot collection --

func collect_seeds(amount: int) -> void:
	_run_seeds += amount

func collect_fragment() -> void:
	_run_fragments += 1

## food_category and food_name match GameState's food model (e.g. "Fruit", "Apple").
func collect_food(food_category: String, food_name: String) -> void:
	_run_food.append({ "category": food_category, "name": food_name })
	GameState.add_food_to_inventory(food_category, food_name)

func collect_ability(ability_key: String) -> void:
	_run_abilities.append(ability_key)
	GameState.unlock_ability_permanent(ability_key)

## -- Serialization --

func serialize() -> Dictionary:
	return {
		"room_index": _current_room_index,
		"seeds": _run_seeds,
		"fragments": _run_fragments,
		"food": _run_food.duplicate(true),
		"abilities": _run_abilities.duplicate(),
	}

func _deserialize_run_state(data: Dictionary) -> void:
	_run_seeds = data.get("seeds", 0)
	_run_fragments = data.get("fragments", 0)
	_run_food = []
	for item: Dictionary in data.get("food", []):
		_run_food.append(item)
	_run_abilities = []
	for item: String in data.get("abilities", []):
		_run_abilities.append(item)

## -- Save helpers --

func _write_save() -> void:
	Saves.write_adventure_run(serialize(), _player.serialize() if _player else {})

## Restore RunManager and GameState from a saved adventure run.
## Used by F6 quick-load. Reloads the saved room and repositions the player.
func _restore_from_save(data: Dictionary) -> void:
	_transitioning = false
	GameState.deserialize(data.get("game_state", {}))
	if Abilities.has_method("deserialize"):
		Abilities.deserialize(data.get("abilities", {}))
	var run_data: Dictionary = data.get("run", {})
	_deserialize_run_state(run_data)
	# Reload the saved room. advance_room() increments before loading, so
	# set index one behind the target.
	_current_room_index = run_data.get("room_index", 0) - 1
	advance_room("")  # no door — player position comes from save data below
	var player_data: Dictionary = data.get("player", {})
	if not player_data.is_empty():
		_restore_player_position.call_deferred(player_data)

func _restore_player_position(player_data: Dictionary) -> void:
	if _player == null:
		return
	var x: float = player_data.get("position_x", _player.global_position.x)
	var y: float = player_data.get("position_y", _player.global_position.y)
	_player.global_position = Vector2(x, y)

## -- Run end --

## Abandons the run without loot transfer (exit to title from pause menu).
func _on_exit_to_title() -> void:
	Saves.delete_adventure_run_save()
	Main.return_to_title()

## Called on voluntary return or room sequence completion.
func return_to_grove() -> void:
	_complete_run()

func _complete_run() -> void:
	# Transfer run loot to persistent state.
	GameState.add_resource("seeds", _run_seeds)
	GameState.add_resource("acorn_fragments", _run_fragments)
	GameState.clear_run_currency()
	# Delete the in-progress run save; write the updated grove state.
	Saves.delete_adventure_run_save()
	Saves.write_game()
	run_completed.emit({
		"seeds": _run_seeds,
		"fragments": _run_fragments,
		"food": _run_food,
		"abilities": _run_abilities,
	})
