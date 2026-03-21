extends CharacterBody2D
class_name Player

# ------------------- variables --------------------- #
@export_category("References")
@export var player_sprite: AnimatedSprite2D
@export var player_collider: CollisionShape2D
@export var spawn_pos: Vector2
@export var sfx: Node
@export var seed_scn: PackedScene
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@export_category("Gameplay")
var can_interact: bool
const DEPOSIT_RANGE: float = 80.0
@export_group("Health")
var current_health: int
@export var max_health: int
var delta_health: int
var is_alive: bool
var is_low_health: bool
var is_dead: bool
@export var seeds_lost: int = 1
var last_damage_pos: Vector2 = Vector2.ZERO
var hurt_cooldown: float = 0.0
const HURT_COOLDOWN_DURATION: float = 2.0
@export_category("Aim Visuals")
@export var aim_max_height: float = 360.0
@export var aim_min_width: float = 0.2
@export var aim_max_width: float = 1.0
@export var sprite_offset_right: float = -4.0
@export var sprite_offset_left: float = 0.0

@export_group("Movement")
@export var move_speed: float
@export var max_move_speed: float
@export var move_acceleration: float
@export var move_friction: float
@export var air_drag: float
var is_moving: bool
var is_midair: bool
var is_stomping: bool
var stomp_grace_period: float = 0.0  # Brief window after stomp where multi-stomps work
const STOMP_GRACE_DURATION: float = 0.15
var bounce_recovering: bool = false
var pending_bounce: bool = false
var is_in_hit_stop: bool = false
# NEW: Track if we need to skip gravity this frame
var _skip_gravity_once: bool = false

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
# Movement
signal just_jumped
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

func _ready() -> void:
	Saves.register_player(self)
	self.position = spawn_pos
	just_spawned.emit()

func _exiting_tree() -> void:
	Saves.unregister_player()

func _find_nearest_shop() -> Node2D:
	var trees := get_tree().get_nodes_in_group("tree")
	var nearest: Node2D = null
	var nearest_dist := DEPOSIT_RANGE
	for tree in trees:
		var shop := tree.get_node_or_null("Shop") as Node2D
		if shop == null:
			continue
		var dist := global_position.distance_to(shop.global_position)
		if dist < nearest_dist:
			nearest_dist = dist
			nearest = shop
	return nearest

func _physics_process(delta: float) -> void:
	if aim_visual.visible:
		update_aim_visual()
	if aim_cooldown > 0:
		aim_cooldown -= delta
	if hurt_cooldown > 0:
		hurt_cooldown -= delta
	if stomp_grace_period > 0:
		stomp_grace_period -= delta

func apply_gravity(delta) -> void:
	# Skip gravity for one frame after bounce to preserve bounce velocity
	if _skip_gravity_once:
		_skip_gravity_once = false
		return
	
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

func jump(is_double_jump: bool = false) -> void:
	velocity.y = -jump_velocity
	
	if is_double_jump:
		velocity.y *= 1.1
		var facing = -1.0 if player_sprite.flip_h else 1.0
		velocity.x += facing * 40.0
	
	jumps_available -= 1
	just_jumped.emit()


func stomp() -> void:
	velocity.y = stomp_velocity
	velocity.x = 0.74 * velocity.x
	is_stomping = true
	just_stomped.emit()

func bounce() -> void:
	if pending_bounce: 
		return
	pending_bounce = true
	_perform_bounce()

func _perform_bounce() -> void:
	
	sfx_stompimpact.play()
	aim_cooldown = 0.5
	
	if is_stomping:
		velocity.y = -jump_velocity * 1.1
		is_stomping = false
		bounce_recovering = true
		stomp_grace_period = STOMP_GRACE_DURATION  # Allow multi-stomps briefly
		
		get_tree().call_group("camera", "apply_shake", Vector2(1, 32), 1.5)
		hit_stop(0.1)
	else:
		velocity.y = -jump_velocity * 0.7
	
	get_tree().create_timer(0.1).timeout.connect(func(): pending_bounce = false)

func hit_stop(duration: float) -> void:
	if is_in_hit_stop: return
	is_in_hit_stop = true
	
	var old_scale = Engine.time_scale
	Engine.time_scale = 0.01

	await get_tree().create_timer(duration, true, false, true).timeout
	
	Engine.time_scale = old_scale
	is_in_hit_stop = false
	
func interact() -> void:
	just_interacted.emit()

func hurt(damage_source_pos: Vector2) -> void:
	if hurt_cooldown > 0:
		return
	
	hurt_cooldown = HURT_COOLDOWN_DURATION
	last_damage_pos = damage_source_pos
	just_hurt.emit()
	lose_seeds(seeds_lost)
	var sm = $StateMachine
	var sm_current = sm.current_state
	if sm_current:
		sm_current.transition_requested.emit(sm_current, HurtState)

func lose_seeds(amount: int) -> void:
	if Economy.get_balance() > 0:
		var actual_loss = min(amount, Economy.get_balance())
		Economy.add_seeds(-actual_loss)
		
		if seed_scn:
			for i in range(actual_loss):
				var lost_seed = seed_scn.instantiate()
				get_tree().current_scene.add_child(lost_seed)
				lost_seed.global_position = global_position
				if lost_seed.has_method("setup_loss"):
					lost_seed.setup_loss()

func _on_entered_interact_area():
	entered_interact_area.emit()
	can_interact = true

func _on_exited_interact_area():
	exited_interact_area.emit()
	can_interact = false

func update_facing_dir(dir: float) -> void:
	if dir > 0:
		# Face Right
		player_sprite.flip_h = false
		player_sprite.position.x = sprite_offset_right
	elif dir < 0:
		# Face Left
		player_sprite.flip_h = true
		player_sprite.position.x = sprite_offset_left

func update_aim_visual() -> void:
	var target_y: float = 360.0
	var current_dist: float
	
	if aim_raycast.is_colliding():
		var collision = aim_raycast.get_collision_point()
		target_y = to_local(collision).y
		current_dist = abs(target_y)
	else:
		# Fallback if no collision (aiming at sky/nothing)
		current_dist = aim_max_height
	
	aim_visual.size.y = target_y
	var dist_factor = clampf(current_dist / aim_max_height, 0.0, 1.0)
	var new_width = lerp(aim_max_width, aim_min_width, dist_factor)
	(aim_visual.material as ShaderMaterial).set_shader_parameter("width_scale", new_width)

func set_time_scale(target_scale: float) -> void:
	Engine.time_scale = target_scale

func serialize() -> Dictionary:
	return {
		"current_health": current_health,
		"max_health": max_health,
		"position_x": global_position.x,
		"position_y": global_position.y,
		"slow_aim": slow_aim,
		"double_jump": double_jump,
	}

func deserialize(data: Dictionary) -> void:
	current_health = data.get("current_health", max_health)
	max_health = data.get("max_health", max_health)
	global_position = Vector2(
		data.get("position_x", spawn_pos.x),
		data.get("position_y", spawn_pos.y)
	)
	slow_aim = data.get("slow_aim", false)
	double_jump = data.get("double_jump", false)
