extends Node2D

@export_group("Spring Settings")
@export var depress_depth: float = 16.0
@export var stiffness: float = 80.0
@export var damping: float = 15.0
@export var mass: float = 2.0

var current_displacement: float = 0.0
var spring_velocity: float = 0.0
var player_on_button: Node2D = null

@onready var buy_prompt: Container = $BuyPromptContainer
@onready var buy_prompt_label: Label = $BuyPromptContainer/BuyPrompt
@onready var seed_cost: int = 5
@onready var btn: Node2D = $Button
@onready var detect_area: Area2D = $Area
@onready var btn_depth: float = 16.0

func _ready():
	buy_prompt.visible = false

func _physics_process(delta):
	var target_y = 0.0
	if player_on_button:
		target_y = depress_depth
	
	var force = (target_y - current_displacement) * stiffness - (spring_velocity * damping)
	
	var acceleration = force / mass
	spring_velocity += acceleration * delta
	current_displacement += spring_velocity * delta
	
	btn.position.y = current_displacement

func _on_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_on_button = body
		show_buy_prompt()
		
		var sm = body.find_child("StateMachine")
		if sm and sm.current_state.name == "Stomp":
			spring_velocity += 150.0
		else:
			spring_velocity += 20.0

func _on_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_on_button = null
		hide_buy_prompt()

func _input(event: InputEvent) -> void:
	if player_on_button and event.is_action_pressed("interact"):
		make_purchase()

func make_purchase() -> void:
	if Game.total_seeds >= seed_cost:
		Game.add_seeds(-seed_cost)
		Game.start_selection_phase(player_on_button.global_position)
		print("purchase accepted")
		# audio feedback
	else:
		print("get more seeds")
		# audio feedback

func show_buy_prompt() -> void:
	buy_prompt_label.text = str("Spend ", seed_cost)
	buy_prompt.visible = true
	
func hide_buy_prompt() -> void:
	buy_prompt.visible = false
