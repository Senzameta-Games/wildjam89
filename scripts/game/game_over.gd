extends CanvasLayer

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.game_over_called.connect(game_over)
	
func game_over() -> void:
	print("game over signal received")
	visible = true
	get_tree().paused = true
	# game over sound


func _on_restart_button_pressed():
	get_tree().paused = false
	get_tree().reload_current_scene()


func _on_exit_button_pressed():
	get_tree().quit()
