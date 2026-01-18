extends CharacterBody2D
class_name Enemy

@export_category("Spawner budget")
@export var spawn_cost: int

@export_category("Movement")
@export var speed: float = 150.0
@export var jump_velocity: float = -400.0

@export_category("Drops")
@export var seed_value: int = 1
@export var seed_scn: PackedScene

var current_target: Node2D = null
signal seed_dropped
signal enemy_defeated

@onready var stomped: bool = false
@onready var is_dying: bool = false

@onready var die_sfx: AudioStreamPlayer2D = $SFX/Die
@onready var enemy_sprite: AnimatedSprite2D = $Sprite
@onready var dropped_seed: Node2D = $Seed


var passive_movement: bool = false
var passive_dir: float = 0.0

# Anti-stuck: track if we've been at same position too long
var stuck_check_timer: float = 0.0
var last_check_pos: Vector2 = Vector2.ZERO
const STUCK_CHECK_INTERVAL: float = 1.0
const STUCK_THRESHOLD: float = 5.0  # If moved less than this, we're stuck

func _ready() -> void:
	$SFX/Spawned.play()
	if not passive_movement:
		aggro_tree()
	else:
		passive_dir = 1.0 if global_position.x < 320.0 else -1.0

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta
	
	# Anti-stuck check
	_check_if_stuck(delta)
	
	move_towards_target()
	move_and_slide()


func no_aggro() -> void:
	passive_movement = true
	current_target = null
	
	if is_inside_tree():
		passive_dir = 1.0 if global_position.x < 320.0 else -1.0

func aggro_player() -> void:
	if passive_movement: return
	current_target = get_tree().get_first_node_in_group("player")
	$Hitbox.set_collision_layer_value(3, false)

func aggro_tree() -> void:
	if passive_movement: return
	
	var trees = get_tree().get_nodes_in_group("tree")
	var valid_trees: Array = []
	
	for t in trees:
		if t is SeedTree:
			valid_trees.append(t)
	
	# Pick a random tree instead of closest - distributes enemies better
	if valid_trees.size() > 0:
		current_target = valid_trees.pick_random()
	else:
		current_target = get_tree().get_first_node_in_group("tree")

func _check_if_stuck(delta: float) -> void:
	if stomped or is_dying or passive_movement:
		return
	
	stuck_check_timer += delta
	if stuck_check_timer >= STUCK_CHECK_INTERVAL:
		stuck_check_timer = 0.0
		
		var distance_moved = global_position.distance_to(last_check_pos)
		if distance_moved < STUCK_THRESHOLD and is_on_floor():
			# We're stuck! Try to pick a different tree or adjust behavior
			_handle_stuck_state()
		
		last_check_pos = global_position

func _handle_stuck_state() -> void:
	# If truly stuck (not near any tree), try picking a new tree
	var trees = get_tree().get_nodes_in_group("tree")
	var near_any_tree = false
	
	for t in trees:
		if t is SeedTree:
			var dist = global_position.distance_to(t.global_position)
			if dist < 80.0:
				near_any_tree = true
				break
	
	# If not near any tree and stuck, pick a new target
	if not near_any_tree:
		var valid_trees: Array = []
		for t in trees:
			if t is SeedTree and t != current_target:
				valid_trees.append(t)
		
		if valid_trees.size() > 0:
			current_target = valid_trees.pick_random()

func move_towards_target() -> void:
	if passive_movement:
		velocity.x = passive_dir * speed
		if enemy_sprite:
			enemy_sprite.play("walk")
			if passive_dir != 0:
				enemy_sprite.flip_h = passive_dir < 0
		return

	if not is_instance_valid(current_target):
		aggro_tree()
		return
	
	# Target the base of the tree - walk straight into it to trigger collision
	var target_x = current_target.global_position.x
	var dir_x = sign(target_x - global_position.x)
	
	# Keep walking toward tree - collision with TreeHitbox will handle damage/death
	velocity.x = dir_x * (speed / 3)
	if enemy_sprite:
		enemy_sprite.play("walk")
		if dir_x != 0:
			enemy_sprite.flip_h = dir_x < 0

func _on_hitbox_body_entered(body: Node2D) -> void:
	#print(body.name)
	if stomped:
		return
	
	if (body != self) and body.is_in_group("player"):
		var is_above = body.global_position.y < (global_position.y -8.0)
		var is_falling = body.velocity.y > 0
		
		if body.get("is_stomping") and is_above and is_falling: 
			if body.has_method("bounce"):
				body.bounce()
			die()
		elif is_above and is_falling:
			if body.has_method("bounce"):
				body.bounce()
		else:
			body.hurt(global_position)

func die() -> void:
	if is_dying: return
	is_dying = true
	remove_from_group("enemy")
	set_physics_process(false)
	$Collider.set_deferred("disabled", true)
	stomped = true
	die_sfx.play()
	squash_and_hide()
	drop_seed()
	var flower_colors = ["green", "blue", "red"]
	var random_color = flower_colors[randi() % 3]
	FlowerManager.add_flower(random_color)
	Game.plant_flower(global_position)

func squash_and_hide() -> void:
	var tween = create_tween()
	tween.tween_property($Sprite, "scale", Vector2(1.4, 0.2), 0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): $Sprite.visible = false)
	$SFX/Squash.play()

func drop_seed() -> void:
	# hide the source node
	if dropped_seed: dropped_seed.visible = false
	
	# emit signals so logic/achievements count right away
	seed_dropped.emit()
	enemy_defeated.emit()
	if Achievements:
		# Determine enemy type for tracking
		var enemy_type: String = "enemy" # default fallback
		
		# Check if it's a Beetle (has its own class)
		if self is Beetle:
			enemy_type = "beetle"
		else:
			# For base Enemy instances, check the scene name or node name
			# Get the scene file path if available
			var scene_file = scene_file_path
			if scene_file != "":
				if "bomb-thrower" in scene_file:
					enemy_type = "beetle"
				elif "slow-strong" in scene_file or "enemy.tscn" == scene_file.get_file():
					enemy_type = "snail"
				elif "fast-weak" in scene_file:
					enemy_type = "worm"
			else:
				# Fallback to checking node name
				if "Snail" in name:
					enemy_type = "snail"
				elif "Worm" in name or "fast" in name.to_lower():
					enemy_type = "worm"
		print(enemy_type)
		Achievements.on_enemy_stomped(enemy_type)
	
	# tie interval to seed value (normalizes seed animation duration)
	var interval = remap(float(seed_value), 1.0, 10.0, 0.2, 0.1)
	interval = clampf(interval, 0.05, 0.2)
	
	# loop through seed value and spawn a sprite
	for i in range(seed_value):
		_spawn_visual_seed()
		
		# wait a short interval before firing another
		if i < seed_value - 1:
			await get_tree().create_timer(interval).timeout
	
	# wait for all the animation to end then die
	await get_tree().create_timer(1.7).timeout
	queue_free()

func _spawn_visual_seed() -> void:
	if not seed_scn: return
	# instantiate a copy of the source node
	var new_seed = seed_scn.instantiate()
	get_tree().current_scene.add_child(new_seed)

	# seed -> enemy
	new_seed.global_position = global_position
	new_seed.visible = true
	
	# find player
	var player = get_tree().get_first_node_in_group("player")
	if player:
		new_seed.setup(player)

	# find and play sound
	var sfx = new_seed.get_node_or_null("SFX/Appear")
	if sfx:
		sfx.play()

func sacrifice() -> void:
	set_physics_process(false)
	$Collider.set_deferred("disabled", true)
	enemy_sprite.play("die")
	die_sfx.play()
	await enemy_sprite.animation_finished
	queue_free()
