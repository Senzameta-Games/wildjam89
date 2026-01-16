extends CharacterBody2D
class_name Enemy

@export_category("Spawner budget")
@export var spawn_cost: int

@export_category("Movement")
@export var speed: float = 150.0
@export var jump_velocity: float = -400.0

@export_category("Drops")
@export var seed_value: int = 1

var current_target: Node2D = null
signal seed_dropped
signal enemy_defeated

@onready var dropped_seed: Node = $Seed
@onready var stomped: bool = false

@onready var enemy_sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	$SFX/Spawned.play()
	aggro_tree()

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_towards_target()
	move_and_slide()

func aggro_player() -> void:
	current_target = get_tree().get_first_node_in_group("player")

func aggro_tree() -> void:
	current_target = get_tree().get_first_node_in_group("tree")

func move_towards_target() -> void:
	var dir_x = sign(current_target.global_position.x - global_position.x)
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
		if body.get("is_stomping"): 
			if body.has_method("bounce"):
				body.bounce()
			die()

func die() -> void:
	set_physics_process(false)
	$Collider.set_deferred("disabled", true)
	stomped = true
	squash_and_hide()
	drop_seed()
	Game.plant_flower(global_position)
	Game.add_seeds(seed_value)

func squash_and_hide() -> void:
	var tween = create_tween()
	tween.tween_property($Sprite, "scale", Vector2(1.4, 0.2), 0.15).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): $Sprite.visible = false)
	$SFX/Squash.play()

func drop_seed() -> void:
	# hide the source node
	dropped_seed.visible = false
	
	# emit signals so logic/achievements count right away
	seed_dropped.emit()
	enemy_defeated.emit()
	if Achievements:
		Achievements.on_enemy_stomped()
	
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
	# instantiate a copy of the source node
	var new_seed = dropped_seed.duplicate()
	add_child(new_seed)
	
	# reset state
	new_seed.position = Vector2.ZERO 
	new_seed.visible = true
	
	# animation
	var tween = create_tween()
	var fuzzy_end_point = randf_range(-36.0, -60.0)
	tween.tween_property(new_seed, "position:y", fuzzy_end_point, 0.5).as_relative().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	var spin_tween = create_tween()
	
	# spin on loop
	spin_tween.set_loops(1) 
	spin_tween.tween_property(new_seed, "scale:x", -1.0, 0.1).set_trans(Tween.TRANS_SINE)
	spin_tween.tween_property(new_seed, "scale:x", 1.0, 0.1).set_trans(Tween.TRANS_SINE)
	
	# find and play sound
	var sfx = new_seed.get_node_or_null("SFX/Appear")
	if sfx:
		tween.tween_callback(sfx.play)
	tween.tween_property(new_seed, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	# clean up
	tween.tween_callback(new_seed.queue_free)

func sacrifice() -> void:
	set_physics_process(false)
	$Collider.set_deferred("disabled", true)
	queue_free()
	
