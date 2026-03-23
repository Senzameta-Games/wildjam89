class_name ArcadeState
extends ModeState

func enter() -> void:
	if Session.game_has_started:
		# Restoring a save — Arcade._ready() already applied all data
		get_tree().paused = false
		return
	# Fresh new run
	Session.start_new_run()
	Achievements.reset_achievements()
	get_tree().paused = false
	if Tutorial and not Tutorial.tutorial_completed:
		Tutorial.reset_tutorial()
		Tutorial.start_tutorial()

func exit() -> void:
	Economy.reset()
	Session.reset()
	FlowerManager.reset_flowers()
	if Achievements:
		Achievements.reset_achievements()
	if MusicPlayer:
		MusicPlayer.fade_to_normal()
	get_tree().paused = false
	get_tree().reload_current_scene()
