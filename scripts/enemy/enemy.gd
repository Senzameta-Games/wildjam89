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
	queue_free()
	
