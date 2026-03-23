class_name PausedState
extends ModeState

var _menu: CanvasLayer

func enter() -> void:
	_menu = context.get_parent().get_node("PauseMenu")
	_menu.resume_requested.connect(_on_resume, CONNECT_ONE_SHOT)
	_menu.restart_requested.connect(_on_restart, CONNECT_ONE_SHOT)
	_menu.return_to_title_requested.connect(_on_return_to_title, CONNECT_ONE_SHOT)
	_menu._pause()  # handles show + async music fade + tree pause internally

func exit() -> void:
	if _menu.resume_requested.is_connected(_on_resume):
		_menu.resume_requested.disconnect(_on_resume)
	if _menu.restart_requested.is_connected(_on_restart):
		_menu.restart_requested.disconnect(_on_restart)
	if _menu.return_to_title_requested.is_connected(_on_return_to_title):
		_menu.return_to_title_requested.disconnect(_on_return_to_title)
	_menu._unpause()
	_menu = null

func _on_resume() -> void:
	transition_requested.emit(self, PlayState)

func _on_restart() -> void:
	Main.restart_run()

func _on_return_to_title() -> void:
	Main.return_to_title()
