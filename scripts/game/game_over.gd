extends CanvasLayer

var achievements_view: CanvasLayer

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	Game.game_over_called.connect(game_over)
	# Find AchievementsView from Main scene (sibling node)
	achievements_view = get_node("../AchievementsView") as CanvasLayer
	
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

func _on_achievements_button_pressed() -> void:
	if achievements_view:
		achievements_view.show_achievements()
