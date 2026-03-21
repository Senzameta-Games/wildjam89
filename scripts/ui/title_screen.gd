extends CanvasLayer

signal start_requested

func _enter_tree() -> void:
	pass

func _ready() -> void:
	pass

func _on_start_button_pressed() -> void:
	start_requested.emit()

func _on_exit_button_pressed() -> void:
	get_tree().quit()
