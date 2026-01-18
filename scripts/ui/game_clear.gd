extends CanvasLayer

@onready var content: Control = $Content
@onready var new_game_plus_btn: Button = $Content/StageClearContainer/NewGamePlus
@onready var quit_btn: Button = $Content/StageClearContainer/QuitToMenu
@onready var header_label: Label = $Content/StageClearContainer/StageClear

func _ready() -> void:
	visible = false
	content.modulate.a = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_screen(_key: String = "") -> void:
	if Game:
		Game.stop_session_timer()
		var final_time = Game.get_session_time_formatted()
		
		# Update the Label Text
		if header_label:
			header_label.text = "You Won in " + final_time
			
	get_tree().paused = true
	
	var reward_icon: TextureRect = $Content/StageClearContainer/Ability/Margin/RewardIcon
		
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
	)

func _on_new_game_plus_pressed() -> void:
	pass

func _on_quit_pressed() -> void:
	if Game:
		Game.game_has_started = false
	get_tree().paused = false
	get_tree().reload_current_scene()
