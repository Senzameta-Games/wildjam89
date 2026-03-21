extends Enemy
class_name Beetle

@export_category("Stats")
@export var hold_dist: float
@export var bomb: PackedScene
@export var buffer: float = 10.0
@export var throw_arc: float

@onready var throw_timer: Timer = $ThrowTimer
@onready var fuzzy_hold_dist = randf_range((hold_dist * 0.5), (hold_dist * 1.2))

@onready var beetle_sprite: AnimatedSprite2D = $Sprite

const SCREEN_MIN_X = 40.0
const SCREEN_MAX_X = 600.0

var about_to_throw: bool = false
var can_throw: bool = true
var my_preferred_side: int = 0  # -1 = left, 1 = right, 0 = either

func _ready() -> void:
	super()
	throw_timer.wait_time = randf_range(2.5, 4.0)  # Randomize throw timing
	throw_timer.timeout.connect(_on_timer_timeout)
	throw_timer.start()
	
	# Pick a preferred side based on spawn position to help spread out
	my_preferred_side = -1 if global_position.x < 320.0 else 1
	
	# Add more variance to hold distance so beetles don't stack
	fuzzy_hold_dist += randf_range(-30.0, 30.0)

# Override aggro_tree to prefer trees that don't already have a beetle targeting them
func aggro_tree() -> void:
	if passive_movement: return
	
	var trees = get_tree().get_nodes_in_group("tree")
	var beetles = get_tree().get_nodes_in_group("enemy").filter(func(e): return e is Beetle and e != self)
	
	var valid_trees: Array = []
	var uncontested_trees: Array = []
	
	for t in trees:
		if t is SeedTree:
			valid_trees.append(t)
			
			# Check if any other beetle is targeting this tree
			var is_contested = false
			for b in beetles:
				if b.current_target == t:
					is_contested = true
					break
			
			if not is_contested:
				uncontested_trees.append(t)
	
	# Prefer uncontested trees
	if uncontested_trees.size() > 0:
		current_target = uncontested_trees.pick_random()
	elif valid_trees.size() > 0:
		current_target = valid_trees.pick_random()
	else:
		current_target = get_tree().get_first_node_in_group("tree")

func move_towards_target() -> void:
	if current_target == null or about_to_throw:
		velocity.x = move_toward(velocity.x, 0, 10)
		return
	
	var target_dir = sign(current_target.global_position.x - global_position.x)
	
	# Use preferred side to offset position and avoid clustering
	var side_offset = my_preferred_side * 20.0
	var target_x = current_target.global_position.x - (target_dir * fuzzy_hold_dist) + side_offset
	var move_dir = sign(target_x - global_position.x)
	
	var future_pos = global_position.x + (move_dir * speed * get_physics_process_delta_time())
	var hitting_wall: bool = false
	
	if move_dir < 0 and future_pos < SCREEN_MIN_X:
		hitting_wall = true
	if move_dir > 0 and future_pos > SCREEN_MAX_X:
		hitting_wall = true
	
	if abs(global_position.x - target_x) > buffer and not hitting_wall:
		velocity.x = move_dir * speed
	else:
		velocity.x = move_toward(velocity.x, 0, 10)
	
	# sprite feedback
	if enemy_sprite:
		if velocity.x != 0:
			enemy_sprite.play("walk")
			enemy_sprite.flip_h = target_dir > 0
		else:
			enemy_sprite.play("idle")
			if current_target:
				enemy_sprite.flip_h = (current_target.global_position.x - global_position.x) > 0

func _on_timer_timeout() -> void:
	if not about_to_throw and current_target:
		beetle_sprite.play("attack")
		prepare_bomb()
		await beetle_sprite.animation_finished
		
		about_to_throw = false
		beetle_sprite.play("idle")

func prepare_bomb() -> void:
	about_to_throw = true
	velocity.x = 0.0
	#print("preparing to bomb")
	
	var throw_delay = 6.0 / 8.0
	
	# form bomb
	if bomb and not stomped:
		var bomb_visual = bomb.instantiate()
		
		# bomb triggers screenshake early without this
		bomb_visual.monitoring = false
		bomb_visual.monitorable = false
		
		add_child(bomb_visual)
		#print("temp bomb has been instantiated")
		
		# kill physics on da bomb until actually thrown
		bomb_visual.process_mode = Node.PROCESS_MODE_DISABLED
		
		# initialize the bomb's position
		bomb_visual.position = Vector2(2 * (1 if enemy_sprite.flip_h else - 8), -2.0)
		
		# sprite feedback
		var bomb_sprite = bomb_visual.get_node("Sprite")
		if bomb_sprite and bomb_sprite is AnimatedSprite2D:
			bomb_sprite.play("default")
		
		# move to beetle hands
		var tween = create_tween()
		var offset_to_hands = Vector2(2 * (1 if enemy_sprite.flip_h else - 1), -12.0)
		tween.tween_property(bomb_visual, "position", offset_to_hands, 0.2)
		
		# throw when tween ends
		tween.tween_callback(func(): throw_bomb(bomb_visual)).set_delay(throw_delay)
		#print("temp bomb has moved to beetle hands")

func throw_bomb(temp_bomb: Node2D) -> void:
	if not is_instance_valid(temp_bomb):
		return

	var spawn_pos = temp_bomb.global_position

	temp_bomb.queue_free()
	
	if bomb:
		var real_bomb = bomb.instantiate()
		get_parent().add_child(real_bomb)
		
		real_bomb.global_position = spawn_pos
		
		if stomped:
			if "harmless" in real_bomb:
				real_bomb.harmless = true
		else: 
			# decide throw direction
			var throw_dir = 1
			if is_instance_valid(current_target):
				throw_dir = sign(current_target.global_position.x - global_position.x)
			else:
				# If target died mid-throw, just throw in the direction the beetle is facing
				# (Assuming flip_h = true is Right, flip_h = false is Left)
				if enemy_sprite.flip_h:
					throw_dir = 1
				else:
					throw_dir = -1
			
			# Fallback if x positions are identical
			if throw_dir == 0: throw_dir = 1
			
			real_bomb.setup(throw_dir, throw_arc)
