class_name RunGameMode
extends ModeState
## Run mode state. Instantiates run.tscn as a child of the main root node.
## On run_completed, returns to grove by transitioning back to GroveGameMode.

@export var run_scene: PackedScene

var _run_instance: Node = null

func enter() -> void:
	if run_scene == null:
		push_error("RunGameMode: run_scene not assigned in inspector")
		return
	_run_instance = run_scene.instantiate()
	# Connect before add_child so the signal is live when _ready() fires.
	if _run_instance.has_signal("run_completed"):
		_run_instance.run_completed.connect(_on_run_completed)
	# Defer add_child to avoid physics-flush errors when transitioning from a
	# body_entered callback (grove To_Run door → RunGameMode.enter()).
	context.call_deferred("add_child", _run_instance)

func exit() -> void:
	if _run_instance != null and is_instance_valid(_run_instance):
		if _run_instance.run_completed.is_connected(_on_run_completed):
			_run_instance.run_completed.disconnect(_on_run_completed)
		_run_instance.queue_free()
	_run_instance = null

func _on_run_completed(_loot: Dictionary) -> void:
	transition_requested.emit(self, GroveGameMode)
