extends State
class_name GroundState

func enter() -> void:
	# TODO Landing feedback
	player.velocity.y = 0
	player.just_landed.emit()

func exit() -> void:
	pass

func update(delta: float) -> void:
	pass

func physics_update(delta: float) -> void:
	# inputs
	var dir = Input.get_axis("move_left", "move_right")
	
	# functions
	player.apply_gravity(delta)
	player.move(dir, delta)
	player.move_and_slide()
	
	# transitions
	if Input.is_action_just_pressed("jump") and player.is_on_floor():
		player.jump()
		transition_requested.emit(self, AirState)
		return
	
	if not player.is_on_floor():
		transition_requested.emit(self, AirState)
		return
