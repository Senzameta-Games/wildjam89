extends CanvasLayer

func _enter_tree() -> void:
	# Only pause and show title screen if game hasn't started yet
	# When restarting, Game.game_has_started will be true, so we skip this
	if not Game.game_has_started:
		# Pause the game as soon as this node enters the tree
		# This happens before _ready(), ensuring nothing starts before we pause
		get_tree().paused = true

func _ready() -> void:
	# Only show title screen if game hasn't started yet
	# This prevents showing it when restarting from pause menu
	visible = not Game.game_has_started

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
