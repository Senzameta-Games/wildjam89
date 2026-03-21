extends CanvasLayer
class_name TutorialTips

@onready var control: Control = $Control

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = true

func show_tips() -> void:

	
	visible = true
	# Fade music to paused pitch
	if MusicPlayer:
		MusicPlayer.fade_to_paused()

func _on_understand_button_pressed() -> void:
	if Tutorial:
		Tutorial.on_tips_acknowledged()

	if MusicPlayer:
		MusicPlayer.fade_to_normal()
	
	Session.start_session_timer()
	
	visible = false
	get_tree().paused = false
