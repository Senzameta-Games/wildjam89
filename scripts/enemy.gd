extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0


@export var seed_value: int = 1
@export var current_target: Node2D = null
signal seed_dropped
signal enemy_defeated

@onready var dropped_seed: Node = $Seed
@onready var stomped: bool = false

@onready var enemy_sprite: AnimatedSprite2D = $Sprite


func _ready() -> void:
	$SFX/Spawned.play()
	aggro_player()

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta
	move_towards_target()
	move_and_slide()

func aggro_player() -> void:
	current_target = get_tree().get_first_node_in_group("player")

func move_towards_target() -> void:
	var dir_x = sign(current_target.global_position.x - global_position.x)
	velocity.x = dir_x * (SPEED / 3)
	if enemy_sprite:
		enemy_sprite.play("walk")
		if dir_x != 0:
			enemy_sprite.flip_h = dir_x < 0

func _on_hitbox_body_entered(body: Node2D) -> void:
	#print(body.name)
	if stomped:
		return
		
	if (body != self) and body.is_in_group("player"):
		var state_machine = body.find_child("StateMachine")
		if state_machine and state_machine.current_state.name == "Stomp":
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
	dropped_seed.visible = true
	var tween = create_tween()
	tween.tween_property(dropped_seed, "position:y", -48.0, 0.48).as_relative().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
	tween.tween_callback(func(): $Seed/SFX/Appear.play())
	tween.tween_property(dropped_seed, "modulate:a", 0.0, 1.2).set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)
	seed_dropped.emit()
	enemy_defeated.emit()
	tween.tween_callback(queue_free)
	
