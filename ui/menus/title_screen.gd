extends CanvasLayer

signal adventure_requested
signal arcade_requested

func _enter_tree() -> void:
	pass

func _ready() -> void:
	pass

func _on_adventure_button_pressed() -> void:
	adventure_requested.emit()

func _on_arcade_button_pressed() -> void:
	arcade_requested.emit()

func _on_exit_button_pressed() -> void:
	get_tree().quit()
