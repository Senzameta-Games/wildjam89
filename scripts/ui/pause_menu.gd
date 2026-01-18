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

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause"):
		if get_tree().paused:
			# If achievements view is open, close it first
			if achievements_view:
				# Check if the Control child is visible
				var control_node = achievements_view.get_node_or_null("Control")
				if control_node and control_node.visible:
					achievements_view.hide_achievements()
					return
			visible = false
			get_tree().paused = false
		else:
			visible = true
			get_tree().paused = true

func _on_resume_button_pressed() -> void:
	visible = false
	get_tree().paused = false

func _on_restart_button_pressed() -> void:
	# Reset the game state, and then reset the Main scene
	Game.reset_game_state()
	 
	var scene = get_tree()	
	scene.paused = false
	scene.reload_current_scene()

func _on_exit_button_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")

func _on_achievements_button_pressed() -> void:
	if achievements_view:
		achievements_view.show_achievements()
