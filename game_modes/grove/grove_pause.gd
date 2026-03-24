extends CanvasLayer

signal return_to_title_requested

var _achievements_view: CanvasLayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_achievements_view = get_node_or_null("../AchievementsView") as CanvasLayer

func _input(_event: InputEvent) -> void:
	if not Input.is_action_just_pressed("pause"):
		return
	get_viewport().set_input_as_handled()
	if not visible:
		_pause()
		return
	# Pause menu is open — close achievements first if visible, otherwise resume
	var control := _achievements_view.get_node_or_null("Control") if _achievements_view else null
	if control and control.visible:
		_achievements_view.hide_achievements()
	else:
		_unpause()

func _pause() -> void:
	visible = true
	if MusicPlayer:
		MusicPlayer.fade_to_paused()
		await get_tree().create_timer(0.35).timeout
	get_tree().paused = true

func _unpause() -> void:
	visible = false
	get_tree().paused = false
	if MusicPlayer:
		MusicPlayer.fade_to_normal()

func _on_resume_button_pressed() -> void:
	_unpause()

func _on_achievements_button_pressed() -> void:
	if _achievements_view:
		_achievements_view.show_achievements()

func _on_options_button_pressed() -> void:
	pass  # TODO: options panel

func _on_exit_button_pressed() -> void:
	get_tree().paused = false
	return_to_title_requested.emit()
