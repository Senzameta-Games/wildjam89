extends State
class_name AirState

func enter() -> void:
	# if as a result of a jump, jump animation
	# if as a result of falling, fall animation
	pass

func physics_update(delta: float) -> void:
	var dir = Input.get_axis("move_left", "move_right")
	
	player.apply_gravity(delta)
	player.move(dir, delta)
	player.move_and_slide()
	
	if player.is_on_floor():
		transition_requested.emit(self, GroundState)
		return
	
	if Input.is_action_just_pressed("stomp"):
		transition_requested.emit(self, StompState)
