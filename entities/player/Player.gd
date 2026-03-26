extends CharacterBody2D
class_name Player

# ------------------- variables --------------------- #
@export_category("References")
@export var player_sprite: AnimatedSprite2D
@export var player_collider: CollisionShape2D
@export var spawn: Marker2D
@export var sfx: Node
@export var seed_scn: PackedScene
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

@export_category("Movement")
@export var move_speed: float
@export var move_acceleration: float
@export var move_friction: float
@export var air_drag: float
@export var jump_velocity: float
@export var stomp_velocity: float
var is_stomping: bool
var is_in_hit_stop: bool = false
var aim_cooldown: float
var jumps_available: int = 0

@export_category("Combat")
@export var seeds_lost: int = 1
const HURT_COOLDOWN_DURATION: float = 2.0
# TODO: Remove — vestigial from jam build; serialized but has no gameplay effect
var current_health: int
@export var max_health: int
var last_damage_pos: Vector2 = Vector2.ZERO
var hurt_cooldown: float = 0.0

@export_category("Aim")
@export var aim_max_height: float = 360.0
@export var aim_min_width: float = 0.2
@export var aim_max_width: float = 1.0
@export var sprite_offset_right: float = -4.0
@export var sprite_offset_left: float = 0.0

const DEPOSIT_RANGE: float = 80.0

# Signals
signal just_spawned
# Combat
signal just_hurt
# Movement
signal just_jumped
# Action
signal just_stomped
# Interaction SM triggers
signal interact_pressed
signal interact_released

# SFX node references accessed by states
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
@onready var interaction_sm: InteractionStateMachine = $InteractionStateMachine

func get_interaction_constraint() -> Dictionary:
	if interaction_sm:
		return interaction_sm.get_movement_constraint()
	return {
		"allow_movement": true,
		"speed_multiplier": 1.0,
		"allow_jump": true,
		"allow_stomp": true,
		"allow_aim": true,
	}

func _ready() -> void:
	Saves.register_player(self)
	if spawn:
		self.position = spawn.position
	# just_spawned always fires — position is set here when spawn is assigned,
	# or overridden by the scene manager (e.g. grove.gd) immediately after _ready().
	just_spawned.emit()
	
func _exit_tree() -> void:
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
	if Input.is_action_just_pressed("interact"):
		interact_pressed.emit()
	if Input.is_action_just_released("interact"):
		interact_released.emit()

func apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y += gravity * delta

func move(dir: float, delta: float) -> void:
	if dir:
		velocity.x = move_toward(velocity.x, dir * move_speed, move_acceleration * delta)
	else:
		if is_on_floor():
			velocity.x = move_toward(velocity.x, 0, move_friction * delta)
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
	velocity.y = max(velocity.y, stomp_velocity)
	velocity.x = 0.74 * velocity.x
	is_stomping = true
	just_stomped.emit()
	hit_stop(0.04)

func bounce() -> void:
	sfx_stompimpact.play()
	aim_cooldown = 0.5
	velocity.y = -jump_velocity * 1.1
	is_stomping = false
	get_tree().call_group("camera", "stomp_character")
	var sm := $StateMachine
	if sm and sm.current_state:
		sm.current_state.transition_requested.emit(sm.current_state, AirState)
	hit_stop(0.1)

func hit_stop(duration: float) -> void:
	if is_in_hit_stop:
		return
	is_in_hit_stop = true

	TimeScaleManager.push(&"hit_stop", 0.01, TimeScaleManager.PRIORITY_HIT_STOP)
	await get_tree().create_timer(duration, true, false, true).timeout
	TimeScaleManager.pop(&"hit_stop")

	is_in_hit_stop = false

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
	# Arcade-coupled: reads and writes Economy. In Adventure mode, Economy is never
	# populated (balance stays 0), so actual_loss = min(amount, 0) = 0 — silent no-op.
	# Future: route to GameState.spend_resource("run_currency", amount) for Adventure.
	if Economy.get_balance() > 0:
		var actual_loss = min(amount, Economy.get_balance())
		Economy.add_seeds(-actual_loss)

		if seed_scn:
			var spawn_pos_val := global_position
			for i in range(actual_loss):
				_deferred_spawn_loss_seed.call_deferred(spawn_pos_val)

func _deferred_spawn_loss_seed(spawn_pos_val: Vector2) -> void:
	var lost_seed = seed_scn.instantiate()
	get_tree().current_scene.add_child(lost_seed)
	lost_seed.global_position = spawn_pos_val
	lost_seed.setup_loss()

func update_facing_dir(dir: float) -> void:
	if dir > 0:
		player_sprite.flip_h = false
		player_sprite.position.x = sprite_offset_right
	elif dir < 0:
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

func serialize() -> Dictionary:
	return {
		"position_x": global_position.x,
		"position_y": global_position.y,
	}

func deserialize(data: Dictionary) -> void:
	# Health fields not saved — vestigial. Read with defaults for old save compatibility.
	current_health = data.get("current_health", max_health)
	max_health = data.get("max_health", max_health)
	var fallback := spawn.position if spawn else global_position
	global_position = Vector2(
		data.get("position_x", fallback.x),
		data.get("position_y", fallback.y)
	)
	# slow_aim / double_jump — removed; ignored here for old save compatibility.
