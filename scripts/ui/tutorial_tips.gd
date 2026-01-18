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
	# Tell tutorial manager tips were acknowledged
	if Tutorial:
		Tutorial.on_tips_acknowledged()
	
	# Fade music back to normal after unpause
	if MusicManager:
		MusicManager.fade_to_normal()
	
	visible = false
