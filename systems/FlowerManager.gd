extends Node

# Flower counts (live flowers currently in the scene)
var green_flowers: int = 0
var blue_flowers: int = 0
var red_flowers: int = 0

# Visual spawning
const GRID_SIZE: int = 16
const FLOWER_HEIGHT: int = 16
var flower_columns: Dictionary = {}
var flower_scene: PackedScene = preload("res://scenes/flower/flower.tscn")
var _flower_positions: Array = []  # exact spawn pos of every flower node, for visual restore on load

# Gameplay bonus constants
const FLOWER_GROWTH_BONUS: float = 0.05
const FLOWER_DEFENSE_BONUS: float = 0.01
const FLOWER_POWERUP_BONUS: float = 0.02

# Blue flower defense values (used by legacy helpers)
const BLUE_DEFENSE_PER_FLOWER: float = 0.01
const BLUE_MAX_DEFENSE: float = 0.80

# Red flower powerup duration values (used by legacy helpers)
const RED_DURATION_PER_FLOWER: float = 0.01
const RED_MAX_DURATION_BONUS: float = 1.0

# Signals
signal flowers_changed(green: int, blue: int, red: int)
signal defense_changed(defense_percent: float)
signal powerup_duration_bonus_changed(bonus_percent: float)

func _ready() -> void:
	reset_flowers()

func reset_flowers() -> void:
	green_flowers = 0
	blue_flowers = 0
	red_flowers = 0
	flower_columns.clear()
	_flower_positions.clear()
	emit_all_signals()

func plant_flower(at_position: Vector2) -> void:
	if flower_scene == null: return

	var grid_index = round(at_position.x / GRID_SIZE)
	var snapped_x = grid_index * GRID_SIZE

	var stack_count = flower_columns.get(grid_index, 0)

	var spawn_pos = Vector2(snapped_x, at_position.y - (stack_count * FLOWER_HEIGHT))
	_flower_positions.append({"x": spawn_pos.x, "y": spawn_pos.y})

	var flower = flower_scene.instantiate()
	get_tree().current_scene.call_deferred_thread_group("add_child", flower)
	flower.global_position = spawn_pos

	flower_columns[grid_index] = stack_count + 1
	if Achievements:
		Achievements.on_flower_planted()

func add_flower(color: String) -> void:
	match color.to_lower():
		"green":
			green_flowers += 1
		"blue":
			blue_flowers += 1
		"red":
			red_flowers += 1
		_:
			push_warning("Unknown flower color: " + color)
			return

	emit_all_signals()

func remove_flower(color: String) -> void:
	match color.to_lower():
		"green":
			green_flowers = max(0, green_flowers - 1)
		"blue":
			blue_flowers = max(0, blue_flowers - 1)
		"red":
			red_flowers = max(0, red_flowers - 1)
		_:
			push_warning("Unknown flower color: " + color)
			return

	emit_all_signals()

# -- Gameplay bonus getters --

func get_flower_growth_bonus() -> float:
	return float(green_flowers) * FLOWER_GROWTH_BONUS

func get_flower_defense_bonus() -> float:
	var reduction = float(blue_flowers) * FLOWER_DEFENSE_BONUS
	return clamp(1.0 - reduction, 0.0, 1.0)

func get_flower_powerup_bonus() -> float:
	return float(red_flowers) * FLOWER_POWERUP_BONUS

# -- Capped helpers (used by defense/powerup UI displays) --

func get_defense_multiplier() -> float:
	var defense = get_defense_percent()
	return 1.0 - defense

func get_defense_percent() -> float:
	var defense = min(blue_flowers * BLUE_DEFENSE_PER_FLOWER, BLUE_MAX_DEFENSE)
	return defense

func get_powerup_duration_multiplier() -> float:
	var bonus = get_powerup_duration_bonus_percent()
	return 1.0 + bonus

func get_powerup_duration_bonus_percent() -> float:
	var bonus = min(red_flowers * RED_DURATION_PER_FLOWER, RED_MAX_DURATION_BONUS)
	return bonus

func emit_all_signals() -> void:
	flowers_changed.emit(green_flowers, blue_flowers, red_flowers)
	defense_changed.emit(get_defense_percent())
	powerup_duration_bonus_changed.emit(get_powerup_duration_bonus_percent())

func restore_visuals() -> void:
	if flower_scene == null: return
	for pos_data in _flower_positions:
		var flower = flower_scene.instantiate()
		flower.global_position = Vector2(pos_data["x"], pos_data["y"])
		get_tree().current_scene.call_deferred_thread_group("add_child", flower)

func serialize() -> Dictionary:
	var columns_str: Dictionary = {}
	for k in flower_columns:
		columns_str[str(k)] = flower_columns[k]
	return {
		"green_flowers": green_flowers,
		"blue_flowers": blue_flowers,
		"red_flowers": red_flowers,
		"flower_columns": columns_str,
		"flower_positions": _flower_positions.duplicate(),
	}

func deserialize(data: Dictionary) -> void:
	green_flowers = data.get("green_flowers", 0)
	blue_flowers = data.get("blue_flowers", 0)
	red_flowers = data.get("red_flowers", 0)
	flower_columns.clear()
	for k in data.get("flower_columns", {}):
		flower_columns[int(k)] = data["flower_columns"][k]
	_flower_positions.clear()
	for pos_data in data.get("flower_positions", []):
		_flower_positions.append(pos_data)
	emit_all_signals()
	restore_visuals()

# Debug helpers
func get_defense_display_text() -> String:
	var defense_percent = get_defense_percent() * 100
	return "%.0f%% (Reduced to %.0f%%)" % [defense_percent, (1.0 - get_defense_percent()) * 100]

func get_powerup_duration_display_text() -> String:
	var bonus_percent = get_powerup_duration_bonus_percent() * 100
	var multiplier = get_powerup_duration_multiplier()
	return "+%.0f%% (x%.2f)" % [bonus_percent, multiplier]
