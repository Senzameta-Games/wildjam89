extends CanvasLayer

# Node References
@onready var content: Control = $Content
@onready var reward_icon: TextureRect = $Content/StageClearContainer/Ability/Margin/RewardIcon
@onready var item_name_label: Label = $Content/StageClearContainer/Ability/Labels/ItemName
@onready var item_desc_label: Label = $Content/StageClearContainer/Ability/Labels/ItemDesc
@onready var flavor_text_label: Label = $Content/StageClearContainer/YouGotTheThing

# Icon Map
@export var ability_icons: Dictionary = {
	"aim_stomp": preload("res://assets/sprites/items/aimstomp/stopwatch.png"),
	"double_jump": preload("res://assets/sprites/items/doublejump/feather.png"),
	"pesticide": preload("res://assets/sprites/items/pesticide/pesticide.png")
}

@export var placeholder_icon: Texture2D

# Text Map
var ability_text: Dictionary = {
	"aim_stomp": {
		"name": "Stopwatch",
		"desc": "While airborne, Fiora can aim with focus."
	},
	"double_jump": {
		"name": "Feather",
		"desc": "Fiora gains a second jump."
	},
	"pesticide": {
		"name": "Bug Zapper",
		"desc": "Lightning strikes 1 enemy / 10 seeds deposited."
	}
}

func _ready() -> void:
	visible = false
	content.modulate.a = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_screen(key: String = "") -> void:
	get_tree().paused = true
	
	# 1. Update Icon
	if ability_icons.has(key):
		reward_icon.texture = ability_icons[key]
	else:
		reward_icon.texture = placeholder_icon
	
	# 2. Update Text
	var display_name = "Item"
	var display_desc = "You found something new!"
	
	if ability_text.has(key):
		var info = ability_text[key]
		display_name = info["name"]
		display_desc = info["desc"]
	
	# Update the labels
	item_name_label.text = display_name
	item_desc_label.text = display_desc
	
	flavor_text_label.text = "You could use the " + display_name + " for something..."
	
	visible = true
	
	# Animation
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

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_accept"):
		hide_screen()
