extends Node

signal ability_unlocked(ability_name: String)

var unlocked_abilities: Dictionary = {
	"aim_stomp": false,
	"double_jump": false,
	"pesticide": false,
}

var seen_abilities: Dictionary = {}

# Randomized power-up system
var ability_queue: Array[String] = []
var recent_abilities: Array[String] = []
const ALL_ABILITIES: Array[String] = ["aim_stomp", "double_jump", "pesticide"]

func unlock_ability(ability_key: String) -> void:
	if ability_key in unlocked_abilities:
		unlocked_abilities[ability_key] = true
		ability_unlocked.emit(ability_key)

func lock_ability(ability_key: String) -> void:
	if ability_key in unlocked_abilities:
		unlocked_abilities[ability_key] = false

func has_ability(ability_key: String) -> bool:
	return unlocked_abilities.get(ability_key, false)

func has_seen_ability(ability_key: String) -> bool:
	return seen_abilities.get(ability_key, false)

func mark_ability_seen(ability_key: String) -> void:
	seen_abilities[ability_key] = true

func _get_ability_reward(_stage: int) -> String:
	if ability_queue.is_empty():
		_init_ability_queue()
	return ability_queue.pop_front()

func _init_ability_queue() -> void:
	# Create a shuffled copy of all abilities
	ability_queue = ALL_ABILITIES.duplicate()
	ability_queue.shuffle()

	# Only prevent repeats if we aren't in the initial "clean slate" phase
	if recent_abilities.size() >= 2:
		var last_two_same = recent_abilities[0] == recent_abilities[1]
		if last_two_same and ability_queue[0] == recent_abilities[0]:
			var repeated = ability_queue.pop_front()
			var insert_pos = randi_range(1, ability_queue.size())
			ability_queue.insert(insert_pos, repeated)

func _get_next_ability() -> String:
	# Refill if empty
	if ability_queue.is_empty():
		_init_ability_queue()

	var next_ability = ability_queue.pop_front()

	# Track recent
	recent_abilities.append(next_ability)
	if recent_abilities.size() > 2:
		recent_abilities.pop_front()

	return next_ability

func _reset_abilities() -> void:
	for key in unlocked_abilities:
		unlocked_abilities[key] = false

func reset() -> void:
	_reset_abilities()
	seen_abilities.clear()
	recent_abilities.clear()
	ability_queue = ALL_ABILITIES.duplicate()
	ability_queue.shuffle()

func serialize() -> Dictionary:
	return {
		"unlocked_abilities": unlocked_abilities.duplicate(),
		"seen_abilities": seen_abilities.duplicate(),
		"ability_queue": ability_queue.duplicate(),
		"recent_abilities": recent_abilities.duplicate(),
	}

func deserialize(data: Dictionary) -> void:
	if data.has("unlocked_abilities"):
		for key in data["unlocked_abilities"]:
			if key in unlocked_abilities:
				unlocked_abilities[key] = data["unlocked_abilities"][key]
	if data.has("seen_abilities"):
		seen_abilities = data["seen_abilities"].duplicate()
	if data.has("ability_queue"):
		ability_queue.assign(data["ability_queue"])
	if data.has("recent_abilities"):
		recent_abilities.assign(data["recent_abilities"])
