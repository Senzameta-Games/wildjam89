extends Node2D
class_name Level

@onready var tree: SeedTree = $Tree
@onready var goal: Node2D = $Goal
@onready var stage_clear_scn = $StageClear

@export var next_level_btn_scn: PackedScene

func _ready():
	var params = Game.get_stage_params()
	
	var spawners = get_tree().get_nodes_in_group("spawner")
	for spawner in spawners:
		if spawner is EnemySpawner:
			spawner.timer_interval = params.spawn_interval
	
	if goal:
		goal.goal_reached.connect(_on_stage_win)

	tree.growth_completed.connect(_on_tree_grown)

func _on_tree_grown() -> void:
	print("Tree max growth")

func _on_stage_win() -> void:
	get_tree().paused = true
	
	var reward = Game.get_stage_params()["ability_reward"]
	if reward != "":
		Game.unlock_ability(reward)
	
	stage_clear_scn.show_screen(reward)
	
	await get_tree().create_timer(3.0).timeout
	
	_purgatory_state()

func _purgatory_state() -> void:
	stage_clear_scn.hide_screen()
	get_tree().paused = false
	get_tree().call_group("spawner", "set_process", false)
	get_tree().call_group("spawners", "set_physics_process", false)
	get_tree().call_group("enemy", "die")
	
	if next_level_btn_scn:
		var btn = next_level_btn_scn.instantiate()
		btn.global_position = Vector2(500, 280)
		call_deferred("add_child", btn)
		
