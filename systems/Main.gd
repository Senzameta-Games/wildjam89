extends Node

# -- Navigation --
# Main is the app shell. It owns all transitions between screens.
# UI scripts call Main; Main decides what state to change and what scene to load.

func _ready() -> void:
	Session.stage_advanced.connect(advance_stage)

func start_new_run() -> void:
	Session.start_new_run()
	Achievements.reset_achievements()
	get_tree().paused = false
	if Tutorial:
		Tutorial.reset_tutorial()
		Tutorial.start_tutorial()

func restart_run() -> void:
	Economy.reset()
	Session.reset()
	FlowerManager.reset_flowers()
	if Achievements:
		Achievements.reset_achievements()
	if MusicPlayer:
		MusicPlayer.fade_to_normal()
	get_tree().paused = false
	get_tree().reload_current_scene()

func return_to_title() -> void:
	Session.game_has_started = false
	if MusicPlayer:
		MusicPlayer.fade_to_normal()
	get_tree().paused = false
	get_tree().reload_current_scene()

func advance_stage() -> void:
	get_tree().reload_current_scene()
