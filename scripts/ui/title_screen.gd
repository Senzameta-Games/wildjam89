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
	
	# Start the music before unpausing
	# Level is a sibling node in the Main scene
	var level = get_node_or_null("../Level")
	if level and level.has_node("Music"):
		var music = level.get_node("Music") as AudioStreamPlayer2D
		if music:
			music.play()
	
	# Hide title screen and unpause to start the game
	visible = false
	get_tree().paused = false

func _on_exit_button_pressed() -> void:
	get_tree().quit()
