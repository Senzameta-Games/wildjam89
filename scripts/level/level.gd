extends Node2D
class_name Level

@onready var tree: SeedTree = $Tree
@onready var goal_spawn: Marker2D = $Goal
@onready var stage_clear_scn = $StageClear

@export var next_level_btn_scn: PackedScene

var goal_scenes: Dictionary = {
	"aim_stomp": preload("res://scenes/goal/stopwatch.tscn"),
	"double_jump": preload("res://scenes/goal/feather.tscn"),
	"acorn": preload("res://scenes/goal/acorn.tscn"),
	# pesticide
	# shield
	# big boots
}

var active_goal: Node2D

func _ready():
	var params = Game.get_stage_params()
	var ability_key = params["ability_reward"]
	
	var spawners = get_tree().get_nodes_in_group("spawner")
	for spawner in spawners:
		if spawner is EnemySpawner:
			spawner.timer_interval = params.spawn_interval
	
	if goal_scenes.has(ability_key):
		var goal_to_spawn = goal_scenes[ability_key]
		active_goal = goal_to_spawn.instantiate()
		# move it to a position
		active_goal.global_position = goal_spawn.global_position
		# add it to the scene tree
		add_child(active_goal)
		# signal for reaching it
		active_goal.goal_reached.connect(_on_stage_win)
		
		if goal_spawn.has_node("Area"):
			goal_spawn.get_node("Area").queue_free()
		goal_spawn.visible = false

	tree.growth_completed.connect(_on_tree_grown)

func _on_tree_grown() -> void:
	print("Tree max growth")

func _on_stage_win() -> void:
	get_tree().paused = true
	
	var reward = Game.get_stage_params()["ability_reward"]
	if reward != "":
		Game.unlock_ability(reward)
	
	if Game.check_win_con():
		_game_clear()
	else:
		stage_clear_scn.show_screen(reward)
		await get_tree().create_timer(3.0).timeout
		_purgatory_state()

func _purgatory_state() -> void:
	stage_clear_scn.hide_screen()
	get_tree().paused = false
	get_tree().call_group("spawner", "set_process", false)
	get_tree().call_group("spawner", "set_physics_process", false)
	get_tree().call_group("enemy", "sacrifice")
	
	if next_level_btn_scn:
		var btn = next_level_btn_scn.instantiate()
		btn.global_position = Vector2(500, 290)
		call_deferred("add_child", btn)
		
func _game_clear() -> void:
	stage_clear_scn.show_screen("GameClear")
	
	var title = stage_clear_scn.get_node("Content/StageClearContainer/StageClear")
	title.text = "ALL GEAR SCAVENGED"
	
	var subtitle = stage_clear_scn.get_node("Content/StageClearContainer/YouGotTheThing")
	subtitle.text = "The trees marvel at the ingenuity of the raccoon"
