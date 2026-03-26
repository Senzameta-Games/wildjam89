class_name GroveManager
extends Node2D
## Owns the grove scene. Manages persistent tree instances, phases, and
## scene transition requests. Internal phase logic (idle/defense/post-defense)
## is handled locally — global state only sees the phase enum via GameState.set_phase().
## Defense sub-state and post-defense are simple method calls, not a formal
## state machine; extract to one only if complexity warrants it later.

signal run_requested         ## Emitted when player enters the run portal.

## Assign in inspector.
@export var tree_scn: PackedScene

@onready var tree_container: Node2D = $Trees
@onready var _pause_menu: CanvasLayer = $GrovePause
@onready var _camera: GroveCamera = $GroveCamera

## tree_id (int) -> SeedTree node
var _tree_instances: Dictionary = {}
var _current_room: RoomArea = null

func _ready() -> void:
	GameState.set_phase(GameState.Phase.GROVE)
	GameState.tree_removed.connect(_on_tree_removed)
	_restore_trees()
	_connect_doors()
	_connect_rooms()
	_pause_menu.return_to_title_requested.connect(func() -> void: Main.return_to_title())
	_place_player_at_initial_spawn()
	var initial_room := get_node_or_null("Rooms/Tutorial0") as RoomArea
	_camera.initialize(initial_room)

func _connect_doors() -> void:
	var doors: Array[Node] = get_tree().get_nodes_in_group("door")
	if doors.is_empty():
		push_warning("GroveManager: no nodes in group 'door' found")
		return
	for door: Node in doors:
		if door.has_signal("door_activated"):
			door.door_activated.connect(_on_run_door_activated)
		# Suppress the body_entered that fires if the player spawns inside
		# this door's area (e.g. both at position 0,0 before layout is finalised).
		if door.has_method("suppress_next_entry"):
			door.suppress_next_entry()

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

## -- Player spawn --

## Positions the Player at the Tutorial0 spawn marker on initial grove entry.
## When returning from a run, grove_state.gd's _apply_run_door_spawn fires
## after _ready() (deferred) and overrides this — no conflict.
func _place_player_at_initial_spawn() -> void:
	var player := get_node_or_null("Player") as Player
	if player == null:
		push_warning("GroveManager: Player node not found — skipping initial spawn placement")
		return
	var spawn := get_node_or_null("Spawns/Player") as Marker2D
	if spawn == null:
		push_warning("GroveManager: Spawns/Player not found — player stays at default position")
		return
	player.global_position = spawn.global_position

## -- Room wiring --

func _connect_rooms() -> void:
	var rooms_node: Node2D = get_node_or_null("Rooms") as Node2D
	if rooms_node == null:
		push_warning("GroveManager: Rooms node not found — skipping room signal connections")
		return
	for child: Node in rooms_node.get_children():
		if child is RoomArea:
			var room: RoomArea = child as RoomArea
			room.player_entered.connect(_camera._on_room_entered)
			room.player_entered.connect(_on_player_entered_room)
			room.player_exited.connect(_on_player_exited_room)

func _on_player_entered_room(room: RoomArea) -> void:
	_current_room = room

func _on_player_exited_room(room: RoomArea) -> void:
	if _current_room == room:
		_current_room = null

## -- Signal handlers --

func _on_tree_removed(tree_id: int) -> void:
	if _tree_instances.has(tree_id):
		var tree: Node2D = _tree_instances[tree_id]
		if is_instance_valid(tree):
			tree.queue_free()
		_tree_instances.erase(tree_id)
