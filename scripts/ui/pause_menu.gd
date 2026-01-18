extends CanvasLayer

var achievements_view: CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false
	# Only unpause if game has started (don't interfere with title screen)
	# The title screen manages pause state on initial load
	if Game.game_has_started:
		get_tree().paused = false
	# Find AchievementsView from Main scene (sibling node)
	achievements_view = get_node("../AchievementsView") as CanvasLayer

func _input(_event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause"):
		if get_tree().paused:
			# If achievements view is open, close it first
			if achievements_view:
				# Check if the Control child is visible
				var control_node = achievements_view.get_node_or_null("Control")
				if control_node and control_node.visible:
					achievements_view.hide_achievements()
					return
			_unpause()
		else:
			_pause()

func _pause() -> void:
	visible = true
	
	# Fade music to paused pitch BEFORE pausing
	if MusicManager:
		MusicManager.fade_to_paused()
		# Wait for fade to complete (fade_duration + small buffer)
		await get_tree().create_timer(0.35).timeout
	
	get_tree().paused = true

func _unpause() -> void:
	visible = false
	get_tree().paused = false
	# Fade music back to normal
	if MusicManager:
		MusicManager.fade_to_normal()

func _on_resume_button_pressed() -> void:
	_unpause()

func _on_restart_button_pressed() -> void:
	# Reset the game state, and then reset the Main scene
	Game.reset_game_state()
	 
	var scene = get_tree()	
	scene.paused = false
	
	# Restore music to normal before scene reload
	if MusicManager:
		MusicManager.fade_to_normal()
	
	scene.reload_current_scene()

func _on_exit_button_pressed() -> void:
	if Game:
		Game.game_has_started = false
	get_tree().paused = false
	
	# Restore music to normal
	if MusicManager:
		MusicManager.fade_to_normal()
	
	get_tree().reload_current_scene()

func _on_achievements_button_pressed() -> void:
	if achievements_view:
		achievements_view.show_achievements()
