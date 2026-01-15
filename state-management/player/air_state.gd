extends State
class_name AirState

func enter() -> void:
	#if Player # has a sprite node:
			#var sprite: AnimatedSprite2D = # that sprite node
			#
		#if velocity.y < 0:
			#sprite.play("jump")
	#else:
		##if velocity.y > 0:
			##sprite.play("falling")
		#pass
		#
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
