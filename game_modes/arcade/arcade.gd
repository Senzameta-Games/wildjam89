extends Node2D
class_name Arcade

@onready var stage_clear_scn = $StageClear
@onready var game_clear_scn = $GameClear
@onready var music: AudioStreamPlayer2D = $Music
@export var zap_sfx: AudioStreamPlayer2D
@onready var tree_meters_ui: TreeMeters = $UI/TreeMeters
@export var next_stage_btn_scn: PackedScene
@export var tree_scn: PackedScene = preload("res://entities/tree/tree.tscn")
@export var acorn_scn: PackedScene = preload("res://entities/tree/acorn_seed.tscn")

var current_reward_key: String = ""

signal stage_won(reward_key: String)
signal game_won()

# --- SPAWNING & SLOTS ---
const MAX_SLOTS = 4
const LEVEL_WIDTH = 640
const SIDE_MARGIN = 160
const SLOT_WIDTH = 80
var occupied_slots: Array[bool] = []
var most_recent_tree: SeedTree

func _ready():
	Saves.register_arcade(self)
	_init_slots()

	if Saves.has_pending_run_load():
		_apply_run_restore(Saves.consume_pending_run_data())
		return

	var params = Session.get_stage_params()
	current_reward_key = params["ability_reward"]
	print("Arcade Ready. Current Reward Key: ", current_reward_key)

	var spawners = get_tree().get_nodes_in_group("spawner")
	for spawner in spawners:
		if spawner is EnemySpawner:
			spawner.timer_interval = params.spawn_interval
			if spawner.has_method("set_spawn_interval"):
				spawner.set_spawn_interval(params.spawn_interval)

	call_deferred("_spawn_new_tree")

	# Start music if game has already started (e.g., from restart)
	# Otherwise, it will start when title screen start button is pressed
	if Session.game_has_started and music:
		music.play()

func _exiting_tree() -> void:
	Saves.unregister_arcade()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		Saves.write_run()
		Saves.debug_print_run_save()
	elif event.is_action_pressed("quick_load"):
		Saves.load_run()
		if Saves.has_pending_run_load():
			get_tree().reload_current_scene()

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
		call_deferred("_spawn_new_tree")

func _on_tree_growth_completed(source_tree: SeedTree) -> void:
	Session.register_tree_grown()
	if Session.check_win_con():
		current_reward_key = "golden_leaf"
	else:
		var params = Session.get_stage_params()
		current_reward_key = params["ability_reward"]
	_spawn_pickup_at_tree(source_tree)

func _spawn_pickup_at_tree(source_tree: SeedTree) -> void:
	var pickup_data := Abilities.get_pickup(current_reward_key)
	if not pickup_data or not pickup_data.pickup_scene:
		push_warning("Arcade: No pickup data or scene for key: " + current_reward_key)
		return

	var pickup = pickup_data.pickup_scene.instantiate()
	add_child(pickup)
	pickup.visible = true
	pickup.z_index = 100
	pickup.collected.connect(_on_reward_collected_from_pickup)
	if pickup.has_method("setup"):
		pickup.setup(current_reward_key)

	var target_pos = Vector2.ZERO
	var found_branch = false

	var branch_manager = source_tree.get_node_or_null("LimbManager")
	if branch_manager:
		var valid_branches = branch_manager.get_limbs_sorted()

		# Need at least 3 branches to exclude top 2 and still have options
		if valid_branches.size() >= 3:
			# Branches are ordered bottom to top (index 0 = lowest)
			# Exclude the top 2 branches
			var eligible_branches = valid_branches.slice(0, valid_branches.size() - 2)

			# Pick from the top portion of eligible branches (highest remaining)
			var pick_from_top = mini(3, eligible_branches.size())
			var high_branches = eligible_branches.slice(eligible_branches.size() - pick_from_top)

			var rand_branch = high_branches.pick_random()

			# Guess side based on first sprite child
			var side_sign = 1
			if rand_branch.get_child_count() > 0:
				var sprite = rand_branch.get_child(0) as Node2D
				if sprite: side_sign = sign(sprite.scale.x)
				if side_sign == 0: side_sign = 1

			target_pos = rand_branch.global_position + Vector2(40 * side_sign, -24)
			found_branch = true

	if not found_branch:
		var presenter = source_tree.get_node_or_null("Presenter")
		var tree_top = presenter._tree_top if presenter else null
		if tree_top:
			target_pos = tree_top.global_position + Vector2(0, -48)
		else:
			target_pos = source_tree.global_position + Vector2(0, -200)

	pickup.global_position = target_pos
	print("Pickup spawned at ", target_pos)

func _on_reward_collected_from_pickup(_pickup_key: String = "") -> void:
	print("Reward collected. Checking type: ", current_reward_key)
	if current_reward_key == "golden_leaf":
		game_won.emit()
		return

	Saves.write_run()
	print("Advancing stage.")

	if current_reward_key != "":
		Abilities.unlock_ability(current_reward_key)

	if not Abilities.has_seen_ability(current_reward_key) and current_reward_key != "":
		Abilities.mark_ability_seen(current_reward_key)
		stage_won.emit(current_reward_key)

	Session.current_stage += 1
	var params = Session.get_stage_params()
	current_reward_key = params["ability_reward"]
	print("Next Stage: ", Session.current_stage, " | Next Reward: ", current_reward_key)

	var spawners = get_tree().get_nodes_in_group("spawner")
	for spawner in spawners:
		if spawner is EnemySpawner:
			spawner.timer_interval = params.spawn_interval
			if spawner.has_method("set_spawn_interval"):
				spawner.set_spawn_interval(params.spawn_interval)

	call_deferred("_spawn_new_tree")

func _spawn_new_tree() -> void:
	var available_indices = []
	for i in range(MAX_SLOTS):
		if not occupied_slots[i]:
			available_indices.append(i)

	if available_indices.is_empty():
		return

	var chosen_slot = available_indices.pick_random()
	occupied_slots[chosen_slot] = true

	var center_x = SIDE_MARGIN + (chosen_slot * SLOT_WIDTH) + (SLOT_WIDTH / 2.0)
	var fuzz = randf_range(-20.0, 20.0)
	var final_x = center_x + fuzz

	if acorn_scn:
		var acorn = acorn_scn.instantiate()
		add_child(acorn)

		var spawn_height = -8.0
		var ground_y = 288.0
		if acorn.has_method("initialize"):
			acorn.initialize(Vector2(final_x, spawn_height), ground_y, chosen_slot)
			acorn.planted.connect(_on_acorn_planted, CONNECT_DEFERRED)

func _on_acorn_planted(slot_index: int, location: Vector2) -> void:
	if not tree_scn: return

	var new_tree = tree_scn.instantiate()
	add_child(new_tree)
	new_tree.global_position = location
	new_tree.slot_index = slot_index

	# add tree to ui
	if tree_meters_ui:
		tree_meters_ui.register_tree(new_tree)

	if not new_tree.growth_completed.is_connected(_on_tree_growth_completed):
		new_tree.growth_completed.connect(_on_tree_growth_completed.bind(new_tree))
	if not new_tree.slot_freed.is_connected(_on_tree_slot_freed):
		new_tree.slot_freed.connect(_on_tree_slot_freed)

	var params = Session.get_stage_params()
	new_tree.damage_per_hit = params["enemy_damage"]

func serialize() -> Dictionary:
	return {
		"occupied_slots": occupied_slots.duplicate(),
		"current_reward_key": current_reward_key,
	}

func deserialize(data: Dictionary) -> void:
	occupied_slots.assign(data.get("occupied_slots", [false, false, false, false]))
	current_reward_key = data.get("current_reward_key", "")

func _apply_run_restore(data: Dictionary) -> void:
	print("[Saves] applying run restore...")

	Session.deserialize(data.get("session", {}))
	Economy.deserialize(data.get("economy", {}))
	Abilities.deserialize(data.get("abilities", {}))
	Achievements.deserialize_run(data.get("achievements_run", {}))
	FlowerManager.deserialize(data.get("flower_manager", {}))
	deserialize(data.get("arcade", data.get("level", {})))

	if Saves._player != null:
		Saves._player.deserialize(data.get("player", {}))


	var params = Session.get_stage_params()
	var spawners = get_tree().get_nodes_in_group("spawner")
	for spawner in spawners:
		if spawner is EnemySpawner:
			spawner.timer_interval = params.spawn_interval
			if spawner.has_method("set_spawn_interval"):
				spawner.set_spawn_interval(params.spawn_interval)

	var respawned_reward := false
	for tree_data in data.get("trees", []):
		var new_tree: SeedTree = tree_scn.instantiate()
		add_child(new_tree)
		new_tree.deserialize(tree_data)
		new_tree.damage_per_hit = params["enemy_damage"]
		if tree_meters_ui:
			tree_meters_ui.register_tree(new_tree)
		if not new_tree.growth_completed.is_connected(_on_tree_growth_completed):
			new_tree.growth_completed.connect(_on_tree_growth_completed.bind(new_tree))
		if not new_tree.slot_freed.is_connected(_on_tree_slot_freed):
			new_tree.slot_freed.connect(_on_tree_slot_freed)

		# Re-drop a pickup if this tree already yielded its reward but
		# the player hadn't collected it yet when the game was saved.
		if not respawned_reward and new_tree.reward_spawned:
			var reward_uncollected := current_reward_key == "golden_leaf" \
				or (current_reward_key != "" and not Abilities.has_seen_ability(current_reward_key))
			if reward_uncollected:
				_spawn_pickup_at_tree(new_tree)
				respawned_reward = true

	if music:
		music.play()

	get_tree().paused = false
	print("[Saves] run restore complete (stage %d)" % Session.current_stage)
