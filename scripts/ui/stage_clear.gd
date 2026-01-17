extends CanvasLayer

@onready var content: Control = $Content
@onready var container = $Content/StageClearContainer
@onready var title_label = $Content/StageClearContainer/StageClear
@onready var reward_label = $Content/StageClearContainer/YouGotTheThing
@onready var reward_icon = $Content/StageClearContainer/RewardIcon

var ability_names: Dictionary = {
	"aim_stomp": "Stopwatch",
	"double_jump": "Feather",
	"acorns": "Acorn Bomb",
	"pesticide": "Bug Zapper",
	"big_stomps": "Big Boots"
}

@export var ability_icons: Dictionary = {}
@export var placeholder_icon: Texture2D

func _ready() -> void:
	visible = false
	content.modulate.a = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_screen(reward_key: String) -> void:
	if reward_key == "":
		reward_label.text = "You win"
		reward_icon.visible = false
		title_label.text = ""
	else:
		var display_name = ability_names.get(reward_key, "Placeholder ability")
		reward_label.text = "You got the %s!" % display_name
		reward_icon.visible = true
		
		if ability_icons.has(reward_key):
			reward_icon.texture = ability_icons[reward_key]
		else:
			reward_icon.texture = placeholder_icon
	
	visible = true
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(content, "modulate:a", 1.0, 0.5)
	
	if reward_icon.visible:
		reward_icon.scale = Vector2.ZERO
		tween.parallel().tween_property(reward_icon, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func hide_screen() -> void:
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(content, "modulate:a", 0.0, 0.5)
	tween.tween_callback(func(): visible = false)
