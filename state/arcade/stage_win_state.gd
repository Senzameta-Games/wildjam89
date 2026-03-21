class_name StageWinState
extends GameState

func enter() -> void:
	var scn := context.get_node("StageClear")
	scn.show_screen(context.current_reward_key)
	scn.screen_dismissed.connect(_on_dismissed, CONNECT_ONE_SHOT)

func exit() -> void:
	pass

func _on_dismissed() -> void:
	transition_requested.emit(self, PlayState)
