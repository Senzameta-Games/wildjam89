extends Node2D

@onready var buy_prompt: Container = $BuyPromptContainer
@onready var buy_prompt_label: Label = $BuyPromptContainer/BuyPrompt
@onready var seed_cost: int = 5
@onready var detect_area: Area2D = $Area

signal shop_interacted

func _ready():
	buy_prompt.visible = false

func _on_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		show_buy_prompt()

func _on_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		hide_buy_prompt()

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		make_purchase()

func make_purchase() -> void:
	if Game.total_seeds >= seed_cost:
		Game.add_seeds(-seed_cost)
		shop_interacted.emit()
		print("purchase accepted")
		# audio feedback
	else:
		print("get more seeds")
		# audio feedback

func show_buy_prompt() -> void:
	buy_prompt_label.text = str("Mulch souls ", seed_cost)
	buy_prompt.visible = true
	
func hide_buy_prompt() -> void:
	buy_prompt.visible = false
