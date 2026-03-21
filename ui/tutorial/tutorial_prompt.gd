extends Control
class_name TutorialPrompt

var target: Node2D = null
var offset: Vector2 = Vector2(0, -60)

@onready var prompt_text: Label = $Panel/VBoxContainer/PromptText

func _ready() -> void:
	# Float animation
	var tween = create_tween().set_loops()
	tween.tween_property(self, "offset:y", offset.y - 5, 0.66).set_trans(Tween.TRANS_CIRC)
	tween.tween_property(self, "offset:y", offset.y + 5, 0.66).set_trans(Tween.TRANS_CIRC)

func _process(_delta: float) -> void:
	if target and is_instance_valid(target):
		# Follow the target
		global_position = target.global_position + offset - (size / 2)
	else:
		queue_free()

func setup(new_target: Node2D, text: String) -> void:
	target = new_target
	if prompt_text:
		prompt_text.text = text
