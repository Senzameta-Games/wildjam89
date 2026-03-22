extends CanvasLayer

signal screen_dismissed

@onready var content: Control = $Content
@onready var restart_btn: Button = $Content/StageClearContainer/RestartButton
@onready var exit_btn: Button = $Content/StageClearContainer/ExitButton
@onready var header_label: Label = $Content/StageClearContainer/StageClear
@onready var reward_icon: TextureRect = $Content/StageClearContainer/Ability/Margin/RewardIcon

func _ready() -> void:
	visible = false
	content.modulate.a = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_screen(_key: String = "") -> void:
	Session.stop_session_timer()
	var final_time = Session.get_session_time_formatted()

	if header_label:
		header_label.text = "You Won in " + final_time

	get_tree().paused = true

	var pickup_data := Abilities.get_pickup("golden_leaf")
	if pickup_data:
		var item_name: Label = $Content/StageClearContainer/Ability/Labels/ItemName
		var item_desc: Label = $Content/StageClearContainer/Ability/Labels/ItemDesc
		if item_name:
			item_name.text = pickup_data.display_name
		if item_desc:
			item_desc.text = pickup_data.description
		if reward_icon and pickup_data.icon:
			reward_icon.texture = pickup_data.icon

	visible = true

	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(content, "modulate:a", 1.0, 1.5)

func hide_screen() -> void:
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(content, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func():
		visible = false
		get_tree().paused = false
		screen_dismissed.emit()
	)

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_accept"):
		hide_screen()

func _on_restart_button_pressed() -> void:
	Main.restart_run()

func _on_exit_button_pressed() -> void:
	Main.return_to_title()
