extends CanvasLayer

func _enter_tree() -> void:
	get_tree().paused = true
	Session.game_has_started = false

func _ready() -> void:
	visible = true

func _on_start_button_pressed() -> void:
	visible = false
	Main.start_new_run()

func _on_exit_button_pressed() -> void:
	get_tree().quit()
