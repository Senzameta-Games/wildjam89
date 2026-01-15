extends State
class_name GroundState

func enter() -> void:
	player.velocity.y = 0
	
	if player.is_stomping:
		stomp_feedback()
	else:
		land_feedback()

func stomp_feedback():
	player.sfx_stomp_impact.play()
	player.player_sprite.play("idle")
	player.is_stomping = false

func land_feedback():
	player.sfx_land.play()
	

func physics_update(delta: float) -> void:
	# inputs
	var dir = Input.get_axis("move_left", "move_right")
	
	# feedback
	if dir != 0:
		player.player_sprite.play("run")
	else:
		player.player_sprite.play("idle")
	
	# functions
	player.apply_gravity(delta)
	player.move(dir, delta)
	player.move_and_slide()
	player.update_facing_dir(dir)
	
	# transitions
	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		player.jump()
		transition_requested.emit(self, AirState)
		return
	
	if not player.is_on_floor():
		transition_requested.emit(self, AirState)
		return
