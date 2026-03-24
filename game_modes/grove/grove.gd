class_name GroveManager
extends Node2D
## Owns the grove scene. Manages persistent tree instances, phases, and
## scene transition requests. Internal phase logic (idle/defense/post-defense)
## is handled locally — global state only sees the phase enum via GameState.set_phase().
## Defense sub-state and post-defense are simple method calls, not a formal
## state machine; extract to one only if complexity warrants it later.

signal run_requested         ## Emitted when player enters the run portal.
signal defense_phase_started
signal defense_phase_ended(flowers_harvested: int)

## Assign in inspector.
@export var tree_scn: PackedScene

@onready var tree_container: Node2D = $Trees
@onready var defense_spawner: Node = $DefenseWaveSpawner
@onready var _pause_menu: CanvasLayer = $GrovePause

## tree_id (int) -> SeedTree node
var _tree_instances: Dictionary = {}

func _ready() -> void:
	GameState.set_phase(GameState.Phase.GROVE)
	GameState.tree_removed.connect(_on_tree_removed)
	_restore_trees()
	_connect_doors()
	_pause_menu.return_to_title_requested.connect(func() -> void: Main.return_to_title())

func _connect_doors() -> void:
	var to_run: Node = get_node_or_null("Doors/To_Run")
	if to_run == null:
		push_warning("GroveManager: Doors/To_Run not found")
		return
	if to_run.has_signal("door_activated"):
		to_run.door_activated.connect(_on_run_door_activated)

func _on_run_door_activated(_door: DoorTrigger) -> void:
	enter_run()

func _restore_trees() -> void:
	for tree_data: Dictionary in GameState.trees:
		_instantiate_tree(tree_data)

func _instantiate_tree(tree_data: Dictionary) -> void:
	if tree_scn == null:
		push_error("GroveManager: tree_scn not assigned in inspector")
		return
	var tree: Node2D = tree_scn.instantiate()
	tree_container.add_child(tree)
	tree.global_position = tree_data["position"]
	if tree.has_method("set_progress"):
		tree.set_progress(tree_data.get("progress", 0.0))
	if tree.has_signal("growth_changed"):
		var tree_id: int = tree_data["id"]
		tree.growth_changed.connect(
			func(new_p: float, _old_p: float) -> void:
				GameState.update_tree_progress(tree_id, new_p)
		)
	_tree_instances[tree_data["id"]] = tree

func plant_new_tree(world_position: Vector2) -> void:
	var id: int = GameState.register_tree(world_position, 10.0)
	_instantiate_tree(GameState.get_tree_data(id))
	Saves.write_game()

## -- Defense phase --

func start_defense_phase() -> void:
	GameState.set_phase(GameState.Phase.DEFENSE)
	defense_phase_started.emit()
	if defense_spawner != null and defense_spawner.has_method("spawn_wave"):
		# Stub: wave data wired up once wave definitions exist.
		defense_spawner.spawn_wave([], 0)

func end_defense_phase() -> void:
	var flowers: int = FlowerManager.wipe_flowers()
	GameState.set_phase(GameState.Phase.GROVE)
	Saves.write_game()
	defense_phase_ended.emit(flowers)

## -- Save / load --

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_save"):
		Saves.write_game()
	elif event.is_action_pressed("quick_load"):
		_reload_from_save()
		Saves.save_toast.emit("Loaded")

## Restore grove state from the last game save.
## Reloads GameState then rebuilds all tree instances to match.
func _reload_from_save() -> void:
	Saves.load_game()
	for tree: Node2D in _tree_instances.values():
		if is_instance_valid(tree):
			tree.queue_free()
	_tree_instances.clear()
	_restore_trees()

## -- Run transition --

## Called when player interacts with the run portal.
## Emits run_requested; the main scene state machine handles the actual transition.
func enter_run() -> void:
	Saves.write_game()
	run_requested.emit()

## -- Signal handlers --

func _on_tree_removed(tree_id: int) -> void:
	if _tree_instances.has(tree_id):
		var tree: Node2D = _tree_instances[tree_id]
		if is_instance_valid(tree):
			tree.queue_free()
		_tree_instances.erase(tree_id)
