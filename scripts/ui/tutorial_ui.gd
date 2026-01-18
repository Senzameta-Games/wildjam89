extends CanvasLayer
class_name TutorialUI

var current_prompt: Control = null
var tips_screen: CanvasLayer = null

@onready var prompt_scene: PackedScene = preload("res://scenes/ui/tutorial_prompt.tscn")
@onready var tips_scene: PackedScene = preload("res://scenes/ui/tutorial_tips.tscn")

func _ready() -> void:
	# Connect to Tutorial signals
	if Tutorial:
		Tutorial.show_tutorial_prompt.connect(_on_show_prompt)
		Tutorial.hide_tutorial_prompt.connect(_on_hide_prompt)
		Tutorial.show_tips_screen.connect(_on_show_tips)

func _on_show_prompt(target: Node2D, text: String) -> void:
	# Remove existing prompt if any
	if current_prompt and is_instance_valid(current_prompt):
		current_prompt.queue_free()
		current_prompt = null
	
	# Wait a frame to ensure old prompt is gone
	await get_tree().process_frame
	
	# Create new prompt
	current_prompt = prompt_scene.instantiate()
	add_child(current_prompt)
	
	if current_prompt.has_method("setup"):
		current_prompt.setup(target, text)

func _on_hide_prompt() -> void:
	if current_prompt and is_instance_valid(current_prompt):
		current_prompt.queue_free()
		current_prompt = null

func _on_show_tips() -> void:
	# Remove prompt if showing
	_on_hide_prompt()
	
	# Create tips screen if it doesn't exist
	if not tips_screen or not is_instance_valid(tips_screen):
		tips_screen = tips_scene.instantiate()
		get_tree().current_scene.add_child(tips_screen)
	
	if tips_screen.has_method("show_tips"):
		tips_screen.show_tips()
