extends CanvasLayer

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	visible = false
	get_tree().paused = false

func _input(event: InputEvent) -> void:
	if Input.is_action_just_pressed("pause"):
		if get_tree().paused:
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
	get_tree().quit()
