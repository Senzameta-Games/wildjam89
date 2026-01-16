extends CharacterBody2D
class_name Player

# ------------------- variables --------------------- #
@export_category("References")
@export var player_sprite: AnimatedSprite2D
@export var player_collider: CollisionShape2D
@export var spawn_pos: Vector2
@export var sfx: Node
var gravity = Game.gravity # Game.gd is an autoload

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
var is_midair: bool
var is_stomping: bool
@export var jump_velocity: float
@export var stomp_velocity: float

# Signals
# General
signal just_spawned
signal entered_interact_area
signal exited_interact_area
# Combat
signal just_hurt
signal just_died
# Movement
signal just_jumped
signal just_landed
# Action
signal just_stomped
signal just_interacted

# making sfx references props of player to be accessed in states
@onready var sfx_jump: AudioStreamPlayer2D = $SFX/Jump
@onready var sfx_step: AudioStreamPlayer2D = $SFX/Step
@onready var sfx_land: AudioStreamPlayer2D = $SFX/Land
@onready var sfx_stompfall: AudioStreamPlayer2D = $SFX/StompFall
@onready var sfx_stompimpact: AudioStreamPlayer2D = $SFX/StompImpact
@onready var sfx_hurt: AudioStreamPlayer2D = $SFX/Hurt
@onready var sfx_heal: AudioStreamPlayer2D = $SFX/Heal

func _ready() -> void:
	self.position = spawn_pos
	just_spawned.emit()

func apply_gravity(delta) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		
func move(dir: float, delta: float) -> void:
	# we are passing movement input
	if dir:
		velocity.x = move_toward(velocity.x, dir * move_speed, move_acceleration * delta)
	# we are not passing movement input	
	else:
		# we stopped moving on the ground
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, move_friction * delta)
		# we stopped moving in the air
		else:
			velocity.x = move_toward(velocity.x, 0, air_drag * delta)

func jump() -> void:
	velocity.y = -jump_velocity
	just_jumped.emit()


func stomp() -> void:
	velocity.y = stomp_velocity
	velocity.x = 0.7 * velocity.x
	is_stomping = true
	just_stomped.emit()

func bounce() -> void:
	velocity.y = -jump_velocity
	
	if is_stomping:
		sfx_stompimpact.play()
		is_stomping = false
		get_tree().call_group("camera", "apply_shake", Vector2(1, 32), 4.0)
	
	move_and_slide()
	
func interact() -> void:
	just_interacted.emit()

func collect_seeds() -> void:
	pass

func hurt(amount: float) -> void:
	just_hurt.emit()

func die() -> void:
	just_died.emit()
	queue_free()

func _on_entered_interact_area():
	entered_interact_area.emit()
	can_interact = true

func _on_exited_interact_area():
	exited_interact_area.emit()
	can_interact = false

func update_facing_dir(dir: float) -> void:
	var default_sprite_offset: float = -8.0
	
	if dir > 0:
		# face right
		player_sprite.flip_h = false
		player_sprite.position.x = default_sprite_offset
	elif dir < 0:
		# face left
		player_sprite.flip_h = true
		player_sprite.position.x = -default_sprite_offset
