extends State
class_name StompState

func enter():
	# play stomp animation
	# play stomp sound fx
	pass

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.stomp()
	player.move_and_slide()
	
	if player.is_on_floor():
		transition_requested.emit(self, GroundState)
		return
