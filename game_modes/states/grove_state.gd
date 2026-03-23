class_name GroveGameMode
extends ModeState
## Main state machine entry point for grove mode.
## Loads the persistent game save and triggers the scene transition.
## Grove's internal phases (idle/defense/post-defense) are managed
## entirely within the grove scene — this state only knows "we're in the grove."

signal transition_to_run_requested

@export var grove_scene: PackedScene

func enter() -> void:
	Saves.load_game()
	if grove_scene == null:
		push_error("GroveGameMode: grove_scene not assigned in inspector")
		return
	get_tree().change_scene_to_packed(grove_scene)
	# After scene change, GroveManager._ready() sets GameState.Phase.GROVE
	# and connects its run_requested signal. The main scene no longer exists
	# in the same frame — wire the run transition in the grove scene's _ready().

func exit() -> void:
	pass
