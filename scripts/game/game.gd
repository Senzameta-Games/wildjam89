extends Node

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")
var trees_grown_count: int = 0
signal game_over_called
signal game_won
signal ability_unlocked(ability_name: String)

# -- Session Timer --
var session_start_time: int = 0
var session_end_time: int = 0

func start_session_timer() -> void:
	session_start_time = Time.get_ticks_msec()

func stop_session_timer() -> void:
	session_end_time = Time.get_ticks_msec()

func get_session_time_formatted() -> String:
	var total_ms = session_end_time - session_start_time
	var total_seconds = int(total_ms / 1000.0)
	var minutes = total_seconds / 60
	var seconds = total_seconds % 60
	return "%02d:%02d" % [minutes, seconds]

var current_stage: int = 1
var unlocked_abilities: Dictionary = {
	"aim_stomp": false,
	"double_jump": false,
	"pesticide": false,
}

var seen_abilities: Dictionary = {}
var game_has_started: bool = false

# Randomized power-up system
var ability_queue: Array[String] = []
var recent_abilities: Array[String] = [] 
const ALL_ABILITIES: Array[String] = ["aim_stomp", "double_jump", "pesticide"]

# -- FIXED CACHE --
# We store the reward AND the stage it was assigned to.
# This prevents the previous stage's reward from persisting if stage_reset is skipped.
var cached_reward: String = ""
var cached_reward_stage: int = -1

func start_new_run() -> void:
	randomize() # Ensure RNG is seeded
	current_stage = 1
	Economy.reset()
	trees_grown_count = 0
	_reset_abilities()
	seen_abilities.clear()
	recent_abilities.clear()
	
	# Force a fresh shuffled deck of the 3 unique abilities
	ability_queue = ALL_ABILITIES.duplicate()
	ability_queue.shuffle()
	
	cached_reward = ""
	cached_reward_stage = -1
	
	game_has_started = true

func next_stage() -> void:
	current_stage += 1
	stage_reset()
	get_tree().reload_current_scene()
	
func stage_reset() -> void:
	Economy.reset()
	flower_columns.clear()
	total_flowers = 0
	# Note: We don't strictly need to clear cache here anymore because
	# get_stage_params checks the stage index, but it's good practice.
	cached_reward = ""
	cached_reward_stage = -1

func get_stage_params() -> Dictionary:
	var difficulty_mult = 1.0 + ((current_stage - 1) * 0.2)
	var base_spawn_interval = 5.0
	var spawn_interval = max(base_spawn_interval / difficulty_mult, 1.5)
	
	# -- LOGIC FIX --
	# 1. Check if we already have a reward assigned for THIS stage index
	if cached_reward == "" or cached_reward_stage != current_stage:
		# 2. If not, get a new one and cache it
		cached_reward = _get_next_ability()
		cached_reward_stage = current_stage
	
	return{
		"spawn_interval": spawn_interval,
		"enemy_damage": 1.2 * difficulty_mult,
		"ability_reward": cached_reward
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

# PASS-THROUGH: migrate callers to Economy directly
signal seeds_changed(current_total: int)

var total_seeds: int:
	get: return Economy.get_balance()
	set(v): Economy.add_seeds(v - Economy.get_balance())

func add_seeds(amount: int) -> void:
	Economy.add_seeds(amount)

const GRID_SIZE: int = 16
const FLOWER_HEIGHT: int = 16

const FLOWER_GROWTH_BONUS: float = 0.05
const FLOWER_DEFENSE_BONUS: float = 0.01
const FLOWER_POWERUP_BONUS: float = 0.02

var flower_scene: PackedScene = preload("res://scenes/flower/flower.tscn")

var flower_columns: Dictionary = {}

signal flower_counts_changed
var flower_counts: Dictionary = {
	"blue": 0,
	"green": 0,
	"red": 0
}
var total_flowers: int = 0

func _ready() -> void:
	flower_columns.clear()
	Economy.seeds_changed.connect(func(val): seeds_changed.emit(val))

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
	Economy.reset()
	trees_grown_count = 0
	flower_columns.clear()
	total_flowers = 0
	flower_counts = {
		"blue": 0,
		"green": 0,
		"red": 0
	}
	flower_counts_changed.emit()
	if Achievements:
		Achievements.reset_achievements()
	
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
			Economy.big_money()
