class_name RunGameMode
extends ModeState
## Main state machine entry point for run mode.
## The actual transition is triggered by grove_state or a GroveManager signal
## connected in main.tscn. This state exists for symmetry and future use
## (e.g. run meta UI, difficulty selection before the run loads).

@export var run_scene: PackedScene

func enter() -> void:
	if run_scene == null:
		push_error("RunGameMode: run_scene not assigned in inspector")
		return
	get_tree().change_scene_to_packed(run_scene)

func exit() -> void:
	pass
