extends State
class_name StompState

func enter():
	player.stomp()
	# play stomp animation
	# play stomp sound fx
	pass

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.move_and_slide()
	
	if player.is_on_floor():
		transition_requested.emit(self, GroundState)
		return
		
	if player.velocity.y < 0:
		transition_requested.emit(self, AirState)
