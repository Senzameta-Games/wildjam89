class_name GameWinState
extends GameState

func enter() -> void:
	Saves.delete_run_save()
	var scn := context.get_node("GameClear")
	scn.show_screen("golden_leaf")
	scn.screen_dismissed.connect(_on_dismissed, CONNECT_ONE_SHOT)

func _on_dismissed() -> void:
	pass
