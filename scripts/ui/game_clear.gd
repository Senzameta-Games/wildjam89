extends CanvasLayer

@onready var content: Control = $Content
@onready var title_label: Label = $Content/StageClearContainer/StageClear
@onready var subtitle_label: Label = $Content/StageClearContainer/YouGotTheThing
# referencing to hide it

func _ready() -> void:
	visible = false
	content.modulate.a = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_screen(_key: String = "") -> void:
	title_label.text = "ALL GEAR SCAVENGED"
	subtitle_label.text = "The trees marvel at the ingenuity of the raccoon"
	var reward_icon: TextureRect = $Content/StageClearContainer/RewardIcon
	if reward_icon:
		reward_icon.visible = false
		
	visible = true
	
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(content, "modulate:a", 1.0, 1.5)

func hide_screen() -> void:
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(content, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): visible = false)
