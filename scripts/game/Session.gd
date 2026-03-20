extends Node

signal game_over_called
signal game_won

var current_stage: int = 1
var trees_grown_count: int = 0
var game_has_started: bool = false

# -- FIXED CACHE --
# We store the reward AND the stage it was assigned to.
# This prevents the previous stage's reward from persisting if stage_reset is skipped.
var cached_reward: String = ""
var cached_reward_stage: int = -1

# -- Session Timer --
var session_start_time: int = 0
var session_end_time: int = 0

func start_new_run() -> void:
	randomize() # Ensure RNG is seeded
	current_stage = 1
	Economy.reset()
	trees_grown_count = 0
	Abilities.reset()
	cached_reward = ""
	cached_reward_stage = -1
	game_has_started = true

func next_stage() -> void:
	current_stage += 1
	stage_reset()
	get_tree().reload_current_scene()

func stage_reset() -> void:
	Economy.reset()
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
		cached_reward = Abilities._get_next_ability()
		cached_reward_stage = current_stage

	return {
		"spawn_interval": spawn_interval,
		"enemy_damage": 1.2 * difficulty_mult,
		"ability_reward": cached_reward
	}

func check_win_con() -> bool:
	var seen_all = Abilities.seen_abilities.size() >= 3
	var grown_enough = trees_grown_count >= 4
	return seen_all and grown_enough

func register_tree_grown() -> void:
	trees_grown_count += 1

func win_game() -> void:
	game_won.emit()

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

func reset() -> void:
	current_stage = 1
	trees_grown_count = 0
	game_has_started = false
	cached_reward = ""
	cached_reward_stage = -1
	session_start_time = 0
	session_end_time = 0
