class_name ArcadeState
extends ModeState
## Arcade mode state. Instantiates arcade.tscn as a child of the main root node
## on enter and removes it on exit. Matches the grove/run instantiation pattern
## so no mode scenes exist in the tree until their state is active.

@export var arcade_scene: PackedScene

var _arcade_instance: Node = null

func enter() -> void:
	if arcade_scene == null:
		push_error("ArcadeState: arcade_scene not assigned in inspector")
		return
	if Session.game_has_started:
		get_tree().paused = false
	else:
		Session.start_new_run()
		Achievements.reset_achievements()
		get_tree().paused = false
		if Tutorial and not Tutorial.tutorial_completed:
			Tutorial.reset_tutorial()
	_arcade_instance = arcade_scene.instantiate()
	context.add_child(_arcade_instance)
	_trigger_fade_in.call_deferred()
	if not Session.game_has_started:
		if Tutorial and not Tutorial.tutorial_completed:
			Tutorial.start_tutorial()

func _trigger_fade_in() -> void:
	await get_tree().process_frame
	ScreenFade.fade_from_black(0.5)

func exit() -> void:
	Economy.reset()
	Session.reset()
	FlowerManager.reset_flowers()
	if Achievements:
		Achievements.reset_achievements()
	if MusicPlayer:
		MusicPlayer.fade_to_normal()
	get_tree().paused = false
	if _arcade_instance != null and is_instance_valid(_arcade_instance):
		_arcade_instance.queue_free()
	_arcade_instance = null
