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
@export var seeds_lost: int = 1
var last_damage_pos: Vector2 = Vector2.ZERO
@export_category("Aim Visuals")
@export var aim_max_height: float = 360.0
@export var aim_min_width: float = 0.2
@export var aim_max_width: float = 1.0

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
var aim_cooldown: float
var can_aim: bool
var jumps_available: int = 0

@export_group("Abilities")
@export var slow_aim: bool = false
@export var double_jump: bool = false

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
@onready var sfx_dash: AudioStreamPlayer2D = $SFX/Dash

@onready var aim_raycast: RayCast2D = $AimRay
@onready var aim_visual: ColorRect = $AimVisual

@onready var big_stomp_zone: Area2D = $BigStompZone

func _ready() -> void:
	self.position = spawn_pos
	just_spawned.emit()

func _physics_process(delta: float) -> void:
	if aim_visual.visible:
		update_aim_visual()
	if aim_cooldown > 0:
		aim_cooldown -= delta

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
	jumps_available -= 1
	just_jumped.emit()


func stomp() -> void:
	velocity.y = stomp_velocity
	velocity.x = 0.69 * velocity.x
	is_stomping = true
	just_stomped.emit()

func do_big_stomp() -> void:
	get_tree().call_group("camera", "apply_shake", Vector2(8, 64), 2.0)
	sfx_land.volume_db = 0.0
	sfx_land.pitch_scale = 0.8
	sfx_land.play()
	
	
	await get_tree().physics_frame
	await get_tree().physics_frame
	
	if big_stomp_zone:
		var bodies = big_stomp_zone.get_overlapping_bodies()
		for body in bodies:
			if body.is_in_group("enemy") and body.has_method("die"):
				if body != self:
					body.die()

func bounce() -> void:
	sfx_stompimpact.play()
	aim_cooldown = 0.5
	if is_stomping:
		velocity.y = -jump_velocity * 1.1
		is_stomping = false
		get_tree().call_group("camera", "apply_shake", Vector2(1, 32), 4.0)
		await hit_stop(0.1)
		
	else: velocity.y = -jump_velocity * 0.7
	
	move_and_slide()

func hit_stop(duration: float) -> void:
	var old_scale = Engine.time_scale
	Engine.time_scale = 0.01
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = old_scale
	
func interact() -> void:
	just_interacted.emit()

func hurt(damage_source_pos: Vector2) -> void:
	just_hurt.emit()
	lose_seeds(seeds_lost)
	var sm = $StateMachine
	var sm_current = sm.current_state
	if sm_current:
		sm_current.transition_requested.emit(sm_current, HurtState)

func lose_seeds(amount: int) -> void:
	if Game.total_seeds > 0:
		var actual_loss = min(amount, Game.total_seeds)
		Game.add_seeds(-actual_loss)

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

func update_aim_visual() -> void:
	var target_y: float = 360.0
	var current_dist: float
	
	if aim_raycast.is_colliding():
		var collision = aim_raycast.get_collision_point()
		target_y = to_local(collision).y
		current_dist = abs(target_y)
	
	aim_visual.size.y = target_y
	var dist_factor = clampf(current_dist / aim_max_height, 0.0, 1.0)
	var new_width = lerp(aim_max_width, aim_min_width, dist_factor)
	(aim_visual.material as ShaderMaterial).set_shader_parameter("width_scale", new_width)

func set_time_scale(target_scale: float) -> void:
	Engine.time_scale = target_scale
