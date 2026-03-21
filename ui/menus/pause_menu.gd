extends CanvasLayer

signal resume_requested
signal restart_requested
signal return_to_title_requested

var achievements_view: CanvasLayer

func _ready() -> void:
	visible = false
	achievements_view = get_node("../AchievementsView") as CanvasLayer

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause") and visible:
		# If achievements view is open, close it first
		var control_node = achievements_view.get_node_or_null("Control") if achievements_view else null
		if control_node and control_node.visible:
			achievements_view.hide_achievements()
			return
		resume_requested.emit()

func _pause() -> void:
	visible = true

	# Fade music to paused pitch BEFORE pausing
	if MusicPlayer:
		MusicPlayer.fade_to_paused()
		# Wait for fade to complete (fade_duration + small buffer)
		await get_tree().create_timer(0.35).timeout

	get_tree().paused = true

func _unpause() -> void:
	visible = false
	get_tree().paused = false
	# Fade music back to normal
	if MusicPlayer:
		MusicPlayer.fade_to_normal()

func _on_resume_button_pressed() -> void:
	resume_requested.emit()

func _on_restart_button_pressed() -> void:
	restart_requested.emit()

func _on_exit_button_pressed() -> void:
	return_to_title_requested.emit()

func _on_achievements_button_pressed() -> void:
	if achievements_view:
		achievements_view.show_achievements()
