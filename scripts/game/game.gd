extends Node

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

signal game_over_called
signal ability_unlocked(ability_name: String)

var current_stage: int = 1
var unlocked_abilities: Dictionary = {
	"aim_stomp": false,
	"double_jump": false,
	"acorns": false,
	"big_stomps": false,
	"pesticide": false,
}

func start_new_run() -> void:
	current_stage = 1
	total_seeds = 0
	_reset_abilities()

func next_stage() -> void:
	current_stage += 1
	get_tree().reload_current_scene()

func get_stage_params() -> Dictionary:
	var difficulty_mult = 1.0 + ((current_stage - 1) * 0.1)
	
	return{
		"spawn_interval": 3.0 / difficulty_mult,
		"enemy_damage": 5.0 * difficulty_mult,
		"ability_reward": _get_ability_reward(current_stage)
	}

func unlock_ability(ability_key: String) -> void:
	if ability_key in unlocked_abilities:
		unlocked_abilities[ability_key] = true
		ability_unlocked.emit(ability_key)

func has_ability(ability_key: String) -> bool:
	return unlocked_abilities.get(ability_key, false)

func _get_ability_reward(stage: int) -> String:
	match stage:
		1: return "aim_stomp"
		2: return "acorns"
		3: return "double_jump"
		4: return "pesticide"
		5: return "big_stomps"
		6: return "tree_shield"
		_: return ""

func check_win_con() -> bool:
	for key in unlocked_abilities:
		if unlocked_abilities[key] == false:
			return false
	return true

func _reset_abilities():
	for key in unlocked_abilities:
		unlocked_abilities[key] = false

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

var flower_scene: PackedScene = preload("res://scenes/flower/flower.tscn")

var flower_columns: Dictionary = {}

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
	# Track for achievements
	if Achievements:
		Achievements.on_flower_planted()

func reset_game_state() -> void:
	total_seeds = 0
	flower_columns.clear()
	seeds_changed.emit(total_seeds)
	# Reset achievements for new run
	if Achievements:
		Achievements.reset_achievements()
		
func _unhandled_input(event):
	if not OS.has_feature("editor"): return
	
	if event:
		if Input.is_action_just_pressed("stopwatch_get"):
			unlock_ability("aim_stomp")
		
		if Input.is_action_just_pressed("acorn_get"):
			unlock_ability("acorns")
		
		if Input.is_action_just_pressed("feather_get"):
			unlock_ability("double_jump")
		
		if Input.is_action_just_pressed("zapper_get"):
			unlock_ability("pesticide")
		
		if Input.is_action_just_pressed("bigboots_get"):
			unlock_ability("big_stomps")
