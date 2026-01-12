extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0

var current_target: Node2D = null

func _ready() -> void:
	$SFX/Spawned.play()
	aggro_player()

func _physics_process(delta: float) -> void:
	# Add the gravity.
	if not is_on_floor():
		velocity += get_gravity() * delta

	## Handle jump.
	#if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		#velocity.y = JUMP_VELOCITY
#
	## Get the input direction and handle the movement/deceleration.
	## As good practice, you should replace UI actions with custom gameplay actions.
	#var direction := Input.get_axis("ui_left", "ui_right")
	#if direction:
		#velocity.x = direction * SPEED
	#else:
		#velocity.x = move_toward(velocity.x, 0, SPEED)
	move_towards_target(delta)
	move_and_slide()

func aggro_player() -> void:
	current_target = get_tree().get_first_node_in_group("player")

func move_towards_target(delta: float) -> void:
	var dir_x = sign(current_target.global_position.x - global_position.x)
	velocity.x = dir_x * (SPEED / 3)

func _on_hitbox_body_entered(body: Node2D) -> void:
	#print(body.name)
	
	if (body != self) and body.is_in_group("player"):
		var state_machine = body.find_child("StateMachine")
		if state_machine and state_machine.current_state.name == "Stomp":
			if body.has_method("bounce"):
				body.bounce()
			die()
		#else:
			#if body.has_method("hurt"):
				#body.hurt() <- if we go the route of having the player recoil from damage.

func die() -> void:
	# other things that happen before the enemy fully dies
	$SFX/Stomped.play()
	queue_free()
