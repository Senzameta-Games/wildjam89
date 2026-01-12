extends CharacterBody2D


const SPEED = 300.0
const JUMP_VELOCITY = -400.0


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

	move_and_slide()



func _on_hitbox_body_entered(body: Node2D) -> void:
	#print(body.name)
	
	# Seems there is some weird behavior in which the newly instantiated Enemy
	# is initially called CharacterBody2D until it becomes Enemy, hence why I'm
	# checking for both in here
	if (body != self) and ('CharacterBody2D' in body.name || 'Enemy' in body.name):
		queue_free()
