extends Node

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

#==================================================================================================#

signal seeds_changed(current_total: int)
signal game_over_called

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
