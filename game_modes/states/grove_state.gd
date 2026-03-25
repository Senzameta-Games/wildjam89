class_name GroveGameMode
extends ModeState
## Grove mode state. Instantiates grove.tscn as a child of the main root node
## rather than replacing the scene, so this state stays alive to broker
## the grove→run transition via GroveManager.run_requested.

@export var grove_scene: PackedScene

var _grove_instance: Node = null
var _returning_from_run: bool = false

func enter() -> void:
	Saves.load_game()
	Saves.write_game()  # create file on first entry; flush run-handoff state on return
	if grove_scene == null:
		push_error("GroveGameMode: grove_scene not assigned in inspector")
		return
	_grove_instance = grove_scene.instantiate()
	# Connect before add_child so no signals emitted during _ready() are missed.
	if _grove_instance.has_signal("run_requested"):
		_grove_instance.run_requested.connect(_on_run_requested)
	# Defer add_child to avoid physics-flush errors when transitioning from a
	# body_entered callback (run → grove via To_Grove door).
	context.call_deferred("add_child", _grove_instance)
	if _returning_from_run:
		# Override player position after the instance is in the tree.
		_apply_run_door_spawn.call_deferred()
		_returning_from_run = false

func exit() -> void:
	if _grove_instance != null and is_instance_valid(_grove_instance):
		_grove_instance.run_requested.disconnect(_on_run_requested)
		_grove_instance.queue_free()
	_grove_instance = null

## Teleport the grove's Player to the run portal's entry marker.
## Called deferred so global_position is valid (node is in the scene tree).
func _apply_run_door_spawn() -> void:
	if _grove_instance == null or not is_instance_valid(_grove_instance):
		return
	var player := _grove_instance.get_node_or_null("Player") as Player
	var to_run_door: Node = _grove_instance.get_node_or_null("Rooms/GroveArea/Doors/To_Run")
	var door_spawn := to_run_door.get_node_or_null("EnterSpawn") as Marker2D if to_run_door else null
	if player != null and door_spawn != null:
		if to_run_door.has_method("suppress_next_entry"):
			to_run_door.suppress_next_entry()
		player.global_position = door_spawn.global_position

func _on_run_requested() -> void:
	_returning_from_run = true
	transition_requested.emit(self, RunGameMode)
