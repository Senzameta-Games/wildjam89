extends CharacterBody2D
class_name Player

# ------------------- variables --------------------- #
@export_category("References")
@export var sprite_reference: AnimatedSprite2D
@export var collider_reference: CollisionShape2D
@export var spawn_pos: Vector2
var gravity = World.gravity # World.gd is an autoload

@export_category("Gameplay")
var can_interact: bool
@export_group("Health")
var current_health: int
@export var max_health: int
var delta_health: int
var is_alive: bool
var is_low_health: bool
var is_dead: bool

@export_group("Movement")
@export var move_speed: float
@export var max_move_speed: float
@export var move_acceleration: float
@export var move_friction: float
@export var air_drag: float
var is_moving: bool
@export var jump_velocity: float
@onready var is_grounded: bool
@onready var is_jumping: bool
@onready var is_falling: bool
@export var stomp_velocity: float
@onready var is_stomping: bool = false

# Signals
# General
signal just_spawned
signal entered_interact_area
signal exited_interact_area
# Health
signal just_healed
signal just_hurt
signal low_health
signal just_died
# Movement
signal just_jumped
signal just_landed
# Action
signal just_stomped
signal just_interacted

func _ready() -> void:
	pass

func _process(delta) -> void:
	pass

func _physics_process(delta) -> void:
	apply_gravity(delta)
	handle_movement(delta)
	handle_jump()
	move_and_slide()

func apply_gravity(delta) -> void:
	if is_on_floor():
		return
	if not is_on_floor():
		velocity.y += gravity * delta
		
func handle_movement(delta: float) -> void:
	if is_stomping:
		return
	var dir = Input.get_axis("move_left", "move_right")
	if dir != 0:
		velocity.x = move_toward(velocity.x, dir * move_speed, move_acceleration * delta)
	else:
		velocity.x = move_toward(velocity.x, 0, move_friction * delta)

func handle_jump() -> void:
	if is_stomping:
		return
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = -jump_velocity

func handle_stomp() -> void:
	pass
	
func handle_interact() -> void:
	pass

func collect_seeds() -> void:
	pass

func take_damage() -> void:
	pass

func player_die() -> void:
	pass

func _unhandled_input(event) -> void:
	pass

func _on_entered_interact_area():
	pass

func _on_exited_interact_area():
	pass
