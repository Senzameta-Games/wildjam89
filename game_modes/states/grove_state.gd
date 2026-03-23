class_name GroveGameMode
extends ModeState
## Grove mode state. Instantiates grove.tscn as a child of the main root node
## rather than replacing the scene, so this state stays alive to broker
## the grove→run transition via GroveManager.run_requested.

@export var grove_scene: PackedScene

var _grove_instance: Node = null

func enter() -> void:
	Saves.load_game()
	if grove_scene == null:
		push_error("GroveGameMode: grove_scene not assigned in inspector")
		return
	_grove_instance = grove_scene.instantiate()
	context.add_child(_grove_instance)
	# Connect the run portal signal now that GroveManager exists
	if _grove_instance.has_signal("run_requested"):
		_grove_instance.run_requested.connect(_on_run_requested)

func exit() -> void:
	if _grove_instance != null and is_instance_valid(_grove_instance):
		_grove_instance.run_requested.disconnect(_on_run_requested)
		_grove_instance.queue_free()
	_grove_instance = null

func _on_run_requested() -> void:
	transition_requested.emit(self, RunGameMode)
