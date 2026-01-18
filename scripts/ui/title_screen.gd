extends CanvasLayer

func _enter_tree() -> void:
	get_tree().paused = true
	if Game: Game.game_has_started = false

func _ready() -> void:
	visible = true

func _on_start_button_pressed() -> void:
	# Reset game state for a new run
	Game.start_new_run()
	Achievements.reset_achievements()
	
	# Reset tutorial for new run
	if Tutorial:
		Tutorial.reset_tutorial()
	
	# Music will start when first tree is planted during tutorial
	
	# Hide title screen and unpause to start the game
	visible = false
	get_tree().paused = false
	
	# Always start tutorial on new run
	if Tutorial:
		Tutorial.start_tutorial()

func _on_exit_button_pressed() -> void:
	get_tree().quit()
