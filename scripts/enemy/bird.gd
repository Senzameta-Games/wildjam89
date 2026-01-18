extends Enemy
class_name Bird

enum BirdBehavior {
	HOVERING,
	ATTACKING
}

@export_category("Bird Stats")
@export var hover_height: float = 120.0
@export var hover_duration: float = 4.0
@export var dive_speed: float = 250.0
@export var patrol_width: float = 60.0
@export var max_attack_duration: float = 3.0 # Maximum time allowed in attack mode

var current_state: BirdBehavior = BirdBehavior.HOVERING

var hover_anchor: Vector2
var hover_timer: float = 0.0
var patrol_time: float = 0.0
var attack_timer: float = 0.0 

func _ready() -> void:
	super()
	
	# -- 1. Pick a side (Upper Left or Upper Right) --
	var screen_center_x = 320.0
	var offset_from_center = 120.0
	var target_x: float
	
	if global_position.x < screen_center_x:
		target_x = screen_center_x - offset_from_center
	else:
		target_x = screen_center_x + offset_from_center
	
	hover_anchor = Vector2(target_x, hover_height)
	current_target = null
	
	current_state = BirdBehavior.HOVERING

func _physics_process(delta: float) -> void:
	if is_dying or stomped:
		velocity += get_gravity() * delta
		move_and_slide()
		return

	# -- State Logic --
	match current_state:
		BirdBehavior.HOVERING:
			_process_hover(delta)
		BirdBehavior.ATTACKING:
			_process_attack(delta)
	
	move_and_slide()
	
	# -- Sprite Facing Logic --
	if enemy_sprite and velocity.x != 0:
		enemy_sprite.flip_h = velocity.x > 0

func _process_hover(delta: float) -> void:
	hover_timer += delta
	patrol_time += delta
	
	# Sine wave wobble
	var wobble_x = sin(patrol_time * 3.0) * patrol_width
	var wobble_y = cos(patrol_time * 2.0) * 15.0
	
	var target_pos = hover_anchor + Vector2(wobble_x, wobble_y)
	var dist = global_position.distance_to(target_pos)
	
	if dist > 5.0:
		velocity = global_position.direction_to(target_pos) * speed
	else:
		velocity = Vector2.ZERO
	
	if enemy_sprite:
		enemy_sprite.play("walk")
	
	if hover_timer >= hover_duration:
		_start_attack_run()

func _start_attack_run() -> void:
	current_state = BirdBehavior.ATTACKING
	hover_timer = 0.0
	attack_timer = 0.0 # Reset attack timer
	
	var possible_targets: Array[Node2D] = []
	

	var player = get_tree().get_first_node_in_group("player")
	if player and is_instance_valid(player):
		possible_targets.append(player)
	
	if possible_targets.size() > 0:
		current_target = possible_targets.pick_random()
		if enemy_sprite:
			enemy_sprite.play("attack")
	else:

		current_state = BirdBehavior.HOVERING

func _process_attack(delta: float) -> void:

	attack_timer += delta

	if attack_timer >= max_attack_duration:
		current_state = BirdBehavior.HOVERING
		return

	if not is_instance_valid(current_target):
		current_state = BirdBehavior.HOVERING
		return

	var dir = global_position.direction_to(current_target.global_position)
	velocity = dir * dive_speed

# Prevent base enemy logic from taking over
func aggro_tree() -> void:
	pass

func aggro_player() -> void:
	pass
