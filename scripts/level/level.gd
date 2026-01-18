extends Node2D
class_name Level

@onready var tree: SeedTree = $Tree
@onready var goal_spawn: Marker2D = $Goal
@onready var stage_clear_scn = $StageClear
@onready var game_clear_scn = $GameClear
@onready var music: AudioStreamPlayer2D = $Music
@onready var zap_sfx: AudioStreamPlayer2D = $Tree/SFX/Zap
@export var next_level_btn_scn: PackedScene

var goal_scenes: Dictionary = {
	"aim_stomp": preload("res://scenes/goal/stopwatch.tscn"),
	"double_jump": preload("res://scenes/goal/feather.tscn"),
	"acorns": preload("res://scenes/goal/acorn.tscn"),
	"pesticide": preload("res://scenes/goal/pesticide.tscn"),
	# shield
	"big_stomps": preload("res://scenes/goal/bigboots.tscn")
}

var active_goal: Node2D

func _ready():
	var params = Game.get_stage_params()
	var ability_key = params["ability_reward"]
	
	var spawners = get_tree().get_nodes_in_group("spawner")
	for spawner in spawners:
		if spawner is EnemySpawner:
			spawner.timer_interval = params.spawn_interval
	
	if tree:
		tree.damage_per_hit = params["enemy_damage"]
		print("Stage ", Game.current_stage, " Damage: ", tree.damage_per_hit)
	
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
	else: # on the last stage, use the default goal (final)
		goal_spawn.visible = true
		if not goal_spawn.goal_reached.is_connected(_on_stage_win):
			goal_spawn.goal_reached.connect(_on_stage_win)

func _on_stage_win() -> void:
	get_tree().paused = true
	
	var reward = Game.get_stage_params()["ability_reward"]
	if reward != "":
		Game.unlock_ability(reward)
	
	if Game.current_stage >= Game.FINAL_STAGE:
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
	get_tree().call_group("flower", "reset")
	
	if next_level_btn_scn:
		var btn = next_level_btn_scn.instantiate()
		btn.global_position = Vector2(500, 290)
		call_deferred("add_child", btn)
		
func _game_clear() -> void:
	game_clear_scn.show_screen("GameClear")
	
