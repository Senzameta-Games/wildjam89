extends Node
class_name FlowerManagerClass

# Flower counts
var green_flowers: int = 0
var blue_flowers: int = 0
var red_flowers: int = 0

# Blue flower defense values
const BLUE_DEFENSE_PER_FLOWER: float = 0.01
const BLUE_MAX_DEFENSE: float = 0.80

# Red flower powerup duration values
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
	emit_all_signals()

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

# Debug helpers
func get_defense_display_text() -> String:
	var defense_percent = get_defense_percent() * 100
	return "%.0f%% (Reduced to %.0f%%)" % [defense_percent, (1.0 - get_defense_percent()) * 100]

func get_powerup_duration_display_text() -> String:
	var bonus_percent = get_powerup_duration_bonus_percent() * 100
	var multiplier = get_powerup_duration_multiplier()
	return "+%.0f%% (x%.2f)" % [bonus_percent, multiplier]
