class_name GameWinState
extends GameState

func enter() -> void:
	Saves.delete_run_save()
	context.get_node("GameClear").show_screen("golden_leaf")
