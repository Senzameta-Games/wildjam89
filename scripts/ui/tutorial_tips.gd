extends CanvasLayer
class_name TutorialTips

@onready var control: Control = $Control

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_tips() -> void:
	visible = true
	# Fade music to paused pitch
	if MusicManager:
		MusicManager.fade_to_paused()

func _on_understand_button_pressed() -> void:
	# Complete the tutorial (this will unpause the game)
	if Tutorial:
		Tutorial.complete_tutorial()
	
	# Fade music back to normal after unpause
	if MusicManager:
		MusicManager.fade_to_normal()
	
	visible = false
