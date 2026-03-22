extends CanvasLayer

signal screen_dismissed

# Node References
@onready var content: Control = $Content
@onready var reward_icon: TextureRect = $Content/StageClearContainer/Ability/Margin/RewardIcon
@onready var item_name_label: Label = $Content/StageClearContainer/Ability/Labels/ItemName
@onready var item_desc_label: Label = $Content/StageClearContainer/Ability/Labels/ItemDesc
@onready var flavor_text_label: Label = $Content/StageClearContainer/YouGotTheThing

@export var placeholder_icon: Texture2D

func _ready() -> void:
	visible = false
	content.modulate.a = 0.0
	process_mode = Node.PROCESS_MODE_ALWAYS

func show_screen(key: String = "") -> void:
	get_tree().paused = true
	
	var pickup_data := Abilities.get_pickup(key)
	var ability := Abilities.get_ability(key)

	if pickup_data:
		reward_icon.texture = pickup_data.icon if pickup_data.icon else placeholder_icon
		item_name_label.text = pickup_data.display_name
		if ability and ability.input_hint != "":
			item_name_label.text += " (" + ability.input_hint + ")"
		item_desc_label.text = pickup_data.description
		flavor_text_label.text = pickup_data.flavor_text
	else:
		reward_icon.texture = placeholder_icon
		item_name_label.text = "Item"
		item_desc_label.text = "You found something new!"
		flavor_text_label.text = ""
	
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
		screen_dismissed.emit()
