class_name TitleScreenState
extends ModeState

func enter() -> void:
	var ui := context.get_node("TitleScreen") as CanvasLayer
	if Saves.is_restoring_run():
		ui.visible = false
		Saves.finish_run_restore()
		transition_requested.emit(self, ArcadeState)
		return
	get_tree().paused = true
	Session.game_has_started = false
	ui.visible = true
	ui.start_requested.connect(_on_start_requested, CONNECT_ONE_SHOT)

func exit() -> void:
	context.get_node("TitleScreen").visible = false
	get_tree().paused = false

func _on_start_requested() -> void:
	transition_requested.emit(self, ArcadeState)
