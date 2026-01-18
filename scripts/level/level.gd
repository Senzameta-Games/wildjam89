extends Node2D
class_name Level

@onready var tree: SeedTree = $Tree
@onready var goal_spawn: Marker2D = $Goal
@onready var stage_clear_scn = $StageClear
@onready var game_clear_scn = $GameClear
@onready var music: AudioStreamPlayer2D = $Music
@onready var zap_sfx: AudioStreamPlayer2D = $Tree/SFX/Zap
@export var next_level_btn_scn: PackedScene
@export var tree_scn: PackedScene = preload("res://scenes/tree/tree.tscn")

var goal_scenes: Dictionary = {
	"aim_stomp": preload("res://scenes/goal/stopwatch.tscn"),
	"double_jump": preload("res://scenes/goal/feather.tscn"),
	"acorns": preload("res://scenes/goal/acorn.tscn"),
	"pesticide": preload("res://scenes/goal/pesticide.tscn"),
	"big_stomps": preload("res://scenes/goal/bigboots.tscn"),
	#"tree_shield": preload("res://scenes/goal/shield.tscn") 
}

var current_reward_key: String = ""

# --- SPAWNING & SLOTS ---
const MAX_SLOTS = 4
const LEVEL_WIDTH = 640
const SIDE_MARGIN = 160
const SLOT_WIDTH = 80 
var occupied_slots: Array[bool] = []
var most_recent_tree: SeedTree

func _ready():
	_init_slots()
	
	var params = Game.get_stage_params()
	current_reward_key = params["ability_reward"]
	print("Level Ready. Current Reward Key: ", current_reward_key)
	
	var spawners = get_tree().get_nodes_in_group("spawner")
	for spawner in spawners:
		if spawner is EnemySpawner:
			spawner.timer_interval = params.spawn_interval
	
	# Setup Initial Tree
	if tree:
		tree.damage_per_hit = params["enemy_damage"]
		
		# Register the initial tree's slot so we don't overlap it
		var best_slot = _get_slot_from_x(tree.global_position.x)
		if best_slot != -1:
			occupied_slots[best_slot] = true
			tree.slot_index = best_slot
			print("Initial tree registered in slot: ", best_slot)
		
		# Connect signals logic
		if not tree.growth_completed.is_connected(_on_tree_growth_completed):
			tree.growth_completed.connect(_on_tree_growth_completed.bind(tree))
		if not tree.slot_freed.is_connected(_on_tree_slot_freed):
			tree.slot_freed.connect(_on_tree_slot_freed)

	# Cleanup placeholder marker
	goal_spawn.visible = false
	if goal_spawn.has_node("Area"):
		goal_spawn.get_node("Area").queue_free()
	
	# Start music if game has already started (e.g., from restart)
	# Otherwise, it will start when title screen start button is pressed
	if Game.game_has_started and music:
		music.play()

func _init_slots():
	occupied_slots.clear()
	for i in range(MAX_SLOTS):
		occupied_slots.append(false)

func _get_slot_from_x(x_pos: float) -> int:
	var start_x = SIDE_MARGIN
	var relative_x = x_pos - start_x
	var index = int(relative_x / SLOT_WIDTH)
	if index >= 0 and index < MAX_SLOTS:
		return index
	return -1 # Out of bounds

func _on_tree_slot_freed(slot_index: int) -> void:
	if slot_index >= 0 and slot_index < occupied_slots.size():
		print("Slot ", slot_index, " freed up!")
		occupied_slots[slot_index] = false

func _on_tree_growth_completed(source_tree: SeedTree) -> void:
	print("Tree growth completed! Attempting to spawn reward: ", current_reward_key)
	
	var goal_scn = null
	if goal_scenes.has(current_reward_key):
		goal_scn = goal_scenes[current_reward_key]
	else:
		print("ERROR: No scene found for key '", current_reward_key, "'. Skipping reward.")
		_on_reward_collected() # Skip to next stage if reward missing
		return

	# Instantiate Goal
	var goal = goal_scn.instantiate()
	add_child(goal)
	goal.visible = true
	goal.z_index = 100
	goal.goal_reached.connect(_on_reward_collected)
	
	# --- POSITIONING LOGIC ---
	# Try to spawn on a branch first
	var target_pos = Vector2.ZERO
	var found_branch = false
	
	var branch_manager = source_tree.get_node_or_null("BranchManager")
	if branch_manager:
		var valid_branches = []
		for b in branch_manager.active_branches:
			if is_instance_valid(b): valid_branches.append(b)
		
		if not valid_branches.is_empty():
			var rand_branch = valid_branches.pick_random()
			# Guess side based on first sprite child
			var side_sign = 1
			if rand_branch.get_child_count() > 0:
				var sprite = rand_branch.get_child(0) as Node2D
				if sprite: side_sign = sign(sprite.scale.x)
				if side_sign == 0: side_sign = 1
			
			target_pos = rand_branch.global_position + Vector2(40 * side_sign, -24)
			found_branch = true
	
	# Fallback: Spawn floating above the tree top
	if not found_branch:
		# Use the visual TreeTop node to find the actual height
		if source_tree.tree_top:
			target_pos = source_tree.tree_top.global_position + Vector2(0, -48)
		else:
			target_pos = source_tree.global_position + Vector2(0, -200)

	goal.global_position = target_pos
	print("Goal spawned at ", target_pos)

func _on_reward_collected() -> void:
	print("Reward collected. Advancing stage.")
	
	if current_reward_key != "":
		Game.unlock_ability(current_reward_key)
	
	if not Game.has_seen_ability(current_reward_key) and current_reward_key != "":
		Game.mark_ability_seen(current_reward_key)
		stage_clear_scn.show_screen(current_reward_key)
	
	# Advance Stage
	Game.current_stage += 1
	var params = Game.get_stage_params()
	current_reward_key = params["ability_reward"]
	print("Next Stage: ", Game.current_stage, " | Next Reward: ", current_reward_key)
	
	# Update Spawners
	var spawners = get_tree().get_nodes_in_group("spawner")
	for spawner in spawners:
		if spawner is EnemySpawner:
			spawner.timer_interval = params.spawn_interval
			
	# Spawn Next Tree
	call_deferred("_spawn_new_tree")

func _spawn_new_tree() -> void:
	# 1. Find Open Slots
	var available_indices = []
	for i in range(MAX_SLOTS):
		if not occupied_slots[i]:
			available_indices.append(i)
	
	if available_indices.is_empty():
		print("Crown Shyness: No slots available for new tree.")
		return
		
	if not tree_scn: return
	
	# 2. Pick Slot & Calculate Pos
	var chosen_slot = available_indices.pick_random()
	occupied_slots[chosen_slot] = true
	
	var center_x = SIDE_MARGIN + (chosen_slot * SLOT_WIDTH) + (SLOT_WIDTH / 2.0)
	var wiggle = randf_range(-20.0, 20.0)
	var final_x = center_x + wiggle
	
	# 3. Instantiate
	var new_tree = tree_scn.instantiate()
	add_child(new_tree)
	new_tree.global_position = Vector2(final_x, 288) # Ground Level Y
	new_tree.slot_index = chosen_slot
	
	# 4. Connect Signals
	if not new_tree.growth_completed.is_connected(_on_tree_growth_completed):
		new_tree.growth_completed.connect(_on_tree_growth_completed.bind(new_tree))
	if not new_tree.slot_freed.is_connected(_on_tree_slot_freed):
		new_tree.slot_freed.connect(_on_tree_slot_freed)
	
	# 5. Apply Stats
	var params = Game.get_stage_params()
	new_tree.damage_per_hit = params["enemy_damage"]
	print("New tree spawned in slot ", chosen_slot, " at X:", final_x)
