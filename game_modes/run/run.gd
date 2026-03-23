class_name RunManager
extends Node2D
## Manages a single run session: room sequencing, loot tracking, and
## the return-to-grove handoff. Food is added to GameState immediately
## on pickup; seeds and fragments transfer on run completion.

signal run_completed(loot: Dictionary)

@export var room_sequence: Array[PackedScene] = []

var _current_room_index: int = -1
var _current_room: Node2D = null
var _run_seeds: int = 0
var _run_fragments: int = 0
var _run_food: Array[Dictionary] = []   ## {category, name} pairs collected this run
var _run_abilities: Array[String] = []

@onready var room_container: Node2D = $RoomContainer

func _ready() -> void:
	GameState.set_phase(GameState.Phase.RUN)
	advance_room()

func advance_room() -> void:
	_current_room_index += 1
	if _current_room_index >= room_sequence.size():
		_complete_run()
		return
	_load_room(room_sequence[_current_room_index])

func _load_room(room_scene: PackedScene) -> void:
	if _current_room != null and is_instance_valid(_current_room):
		_current_room.queue_free()
	_current_room = room_scene.instantiate() as Node2D
	room_container.add_child(_current_room)
	if _current_room.has_signal("room_cleared"):
		_current_room.room_cleared.connect(advance_room)

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

## -- Run end --

## Called on voluntary return or room sequence completion.
func return_to_grove() -> void:
	_complete_run()

func _complete_run() -> void:
	GameState.add_resource("seeds", _run_seeds)
	GameState.add_resource("acorn_fragments", _run_fragments)
	GameState.clear_run_currency()
	Saves.write_game()
	run_completed.emit({
		"seeds": _run_seeds,
		"fragments": _run_fragments,
		"food": _run_food,
		"abilities": _run_abilities,
	})
