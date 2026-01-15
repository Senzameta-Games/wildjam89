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

func _ready() -> void:
	self.position = spawn_pos
	just_spawned.emit()

func apply_gravity(delta) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta
		
func move(dir: float, delta: float) -> void:
	if dir != 0:
		velocity.x = move_toward(velocity.x, dir * move_speed, move_acceleration * delta)
		is_moving = true
		if is_midair == false:
			player_sprite.play("run")
	
		if dir == 1:
			player_sprite.flip_h = false
		elif dir == -1:
			player_sprite.flip_h = true

	else:
		velocity.x = move_toward(velocity.x, 0, move_friction * delta)
		is_moving = false
		player_sprite.play("idle")

func jump() -> void:
	velocity.y = -jump_velocity
	player_sprite.play("jump")
	just_jumped.emit()
	is_midair = true
	$SFX/Jump.play()

func stomp() -> void:
	velocity.y = stomp_velocity
	$SFX/StompFall.play()
	just_stomped.emit()

func bounce() -> void:
	velocity.y = -jump_velocity
	move_and_slide()
	
func interact() -> void:
	just_interacted.emit()

func collect_seeds() -> void:
	pass

func hurt() -> void:
	just_hurt.emit()

func die() -> void:
	just_died.emit()
	queue_free()

func land() -> void:
	$SFX/Land.play()
	is_midair = false
	just_landed.emit()

func _on_entered_interact_area():
	entered_interact_area.emit()
	can_interact = true

func _on_exited_interact_area():
	exited_interact_area.emit()
	can_interact = false
