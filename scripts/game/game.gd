extends Node

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var trees_grown_count: int = 0 # win state looks for 4
signal game_over_called
signal game_won
signal ability_unlocked(ability_name: String)


var current_stage: int = 1
var unlocked_abilities: Dictionary = {
	"aim_stomp": false,
	"double_jump": false,
	"pesticide": false,
}

var seen_abilities: Dictionary = {}
var game_has_started: bool = false

func start_new_run() -> void:
	current_stage = 1
	total_seeds = 0
	_reset_abilities()
	seen_abilities.clear()
	game_has_started = true

func next_stage() -> void:
	current_stage += 1
	stage_reset()
	get_tree().reload_current_scene()
	
func stage_reset() -> void:
	total_seeds = 0
	flower_columns.clear()
	total_flowers = 0
	seeds_changed.emit(total_seeds)

func get_stage_params() -> Dictionary:
	var difficulty_mult = 1.0 + ((current_stage - 1) * 0.5)
	
	return{
		"spawn_interval": 3.0 / difficulty_mult,
		"enemy_damage": 5.0 * difficulty_mult,
		"ability_reward": _get_ability_reward(current_stage)
	}

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

func _get_ability_reward(stage: int) -> String:
	match stage:
		1: return "aim_stomp"
		2: return "double_jump"
		3: return "pesticide"
		_: 
			var all_keys = ["aim_stomp", "double_jump", "pesticide"]
			return all_keys.pick_random()

func check_win_con() -> bool:
	var seen_all = seen_abilities.size() >= 3 
	var grown_enough = trees_grown_count >= 4
	return seen_all and grown_enough

func _reset_abilities():
	for key in unlocked_abilities:
		unlocked_abilities[key] = false

func register_tree_grown() -> void:
	trees_grown_count += 1

func win_game() -> void:
	game_won.emit()

#==================================================================================================#

signal seeds_changed(current_total: int)
var total_seeds: int = 0

func add_seeds(amount: int) -> void:
	total_seeds += amount
	seeds_changed.emit(total_seeds)
	print("Seeds collected: ", total_seeds)
	# Track for achievements
	if Achievements:
		for i in range(amount):
			Achievements.on_seed_collected()
	
#==================================================================================================#

const GRID_SIZE: int = 16
const FLOWER_HEIGHT: int = 16

# Flower bonus constants (per flower)
const FLOWER_GROWTH_BONUS: float = 0.03
const FLOWER_DEFENSE_BONUS: float = 0.02
const FLOWER_POWERUP_BONUS: float = 0.01

var flower_scene: PackedScene = preload("res://scenes/flower/flower.tscn")

var flower_columns: Dictionary = {}

# Track flowers by color
signal flower_counts_changed
var flower_counts: Dictionary = {
	"blue": 0,
	"green": 0,
	"red": 0
}
var total_flowers: int = 0

func _ready() -> void:
	flower_columns.clear()

func plant_flower(at_position: Vector2) -> void:
	if flower_scene == null: return
	
	var grid_index = round(at_position.x / GRID_SIZE)
	var snapped_x = grid_index * GRID_SIZE
	
	var stack_count = flower_columns.get(grid_index, 0)
	
	var spawn_pos = Vector2(snapped_x, at_position.y - (stack_count * FLOWER_HEIGHT))
	
	var flower = flower_scene.instantiate()
	get_tree().current_scene.call_deferred_thread_group("add_child", flower)
	flower.global_position = spawn_pos
	
	flower_columns[grid_index] = stack_count + 1
	# Note: flower will call add_flower() with its color in _ready()
	# Track for achievements
	if Achievements:
		Achievements.on_flower_planted()

func add_flower(color: String) -> void:
	if flower_counts.has(color):
		flower_counts[color] += 1
		total_flowers += 1
		flower_counts_changed.emit()

func remove_flower(color: String) -> void:
	if flower_counts.has(color) and flower_counts[color] > 0:
		flower_counts[color] -= 1
		total_flowers = max(0, total_flowers - 1)
		flower_counts_changed.emit()

func get_flower_growth_bonus() -> float:
	return float(flower_counts.get("green", 0)) * FLOWER_GROWTH_BONUS

func get_flower_defense_bonus() -> float:
	var reduction = float(flower_counts.get("blue", 0)) * FLOWER_DEFENSE_BONUS
	return clamp(1.0 - reduction, 0.0, 1.0)

func get_flower_powerup_bonus() -> float:
	return float(flower_counts.get("red", 0)) * FLOWER_POWERUP_BONUS

func reset_game_state() -> void:
	total_seeds = 0
	flower_columns.clear()
	total_flowers = 0
	flower_counts = {
		"blue": 0,
		"green": 0,
		"red": 0
	}
	seeds_changed.emit(total_seeds)
	flower_counts_changed.emit()
	# Reset achievements for new run
	if Achievements:
		Achievements.reset_achievements()
	
func big_money() -> void:
	total_seeds = 999
		
func _unhandled_input(event):
	if not OS.has_feature("editor"): return
	
	if event:
		if Input.is_action_just_pressed("stopwatch_get"):
			unlock_ability("aim_stomp")
		
		if Input.is_action_just_pressed("feather_get"):
			unlock_ability("double_jump")
		
		if Input.is_action_just_pressed("zapper_get"):
			unlock_ability("pesticide")
		
		if Input.is_action_just_pressed("big_money"):
			big_money()
