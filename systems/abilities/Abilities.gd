extends Node

signal ability_unlocked(ability_key: String)

# Loaded from .tres definitions
var _pickups: Dictionary = {}   # key -> PickupData
var _abilities: Dictionary = {} # key -> AbilityData

# Runtime state
var unlocked_abilities: Dictionary = {}  # key -> bool
var seen_abilities: Dictionary = {}

# Randomized power-up queue
var ability_queue: Array[String] = []
var recent_abilities: Array[String] = []

func _ready() -> void:
	_load_definitions()
	# Initialize unlock dict from loaded abilities
	for key in _abilities:
		if key not in unlocked_abilities:
			unlocked_abilities[key] = false

func _load_definitions() -> void:
	var dir_path := "res://systems/abilities/definitions/"
	var dir := DirAccess.open(dir_path)
	if not dir:
		push_error("Abilities: Could not open definitions directory: " + dir_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var resource = load(dir_path + file_name)
			if resource is PickupData:
				_pickups[resource.pickup_key] = resource
			elif resource is AbilityData:
				_abilities[resource.ability_key] = resource
		file_name = dir.get_next()
	dir.list_dir_end()

	print("Abilities: Loaded %d pickups, %d abilities" % [_pickups.size(), _abilities.size()])

# -- Lookups --

func get_pickup(key: String) -> PickupData:
	return _pickups.get(key)

func get_ability(key: String) -> AbilityData:
	return _abilities.get(key)

func get_all_ability_keys() -> Array[String]:
	var keys: Array[String] = []
	keys.assign(_abilities.keys())
	return keys

func get_all_pickup_keys() -> Array[String]:
	var keys: Array[String] = []
	keys.assign(_pickups.keys())
	return keys

func get_ability_pickups() -> Array[PickupData]:
	var result: Array[PickupData] = []
	for c in _pickups.values():
		if c.grant_type == PickupData.GrantType.ABILITY:
			result.append(c)
	return result

# -- Unlock state --

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

# -- Randomized queue --

func _get_next_ability() -> String:
	if ability_queue.is_empty():
		_refill_queue()
	var next_ability = ability_queue.pop_front()
	recent_abilities.append(next_ability)
	if recent_abilities.size() > 2:
		recent_abilities.pop_front()
	return next_ability

func _refill_queue() -> void:
	ability_queue = get_all_ability_keys()
	ability_queue.shuffle()
	if recent_abilities.size() >= 2:
		var last_two_same = recent_abilities[0] == recent_abilities[1]
		if last_two_same and not ability_queue.is_empty() and ability_queue[0] == recent_abilities[0]:
			var repeated = ability_queue.pop_front()
			var insert_pos = randi_range(1, ability_queue.size())
			ability_queue.insert(insert_pos, repeated)

# -- Reset --

func reset() -> void:
	for key in unlocked_abilities:
		unlocked_abilities[key] = false
	seen_abilities.clear()
	recent_abilities.clear()
	ability_queue = get_all_ability_keys()
	ability_queue.shuffle()

# -- Serialization --

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

## Unlock an ability collected in the world (run rooms, grove rewards).
## Silently no-ops if already unlocked.
## Call site should be GameState.unlock_ability_permanent(); this method
## exists so Abilities remains the runtime authority on unlock flags.
func unlock_ability_from_world(ability_key: String) -> void:
	if has_ability(ability_key):
		return
	unlock_ability(ability_key)
