extends State
class_name AirState

func enter() -> void:
	if player.velocity.y < 0:
		jump_feedback()
	else:
		fall_feedback()
	
func physics_update(delta: float) -> void:
	var dir = Input.get_axis("move_left", "move_right")
	
	player.apply_gravity(delta)
	player.move(dir, delta)
	player.move_and_slide()
	player.update_facing_dir(dir)
	
	if player.is_on_floor():
		transition_requested.emit(self, GroundState)
		return
	
	if Input.is_action_just_pressed("stomp"):
		transition_requested.emit(self, StompState)

func jump_feedback():
	player.player_sprite.play("jump")
	player.sfx_jump.play()
	# other jumping feedback here

func fall_feedback():
	player.player_sprite.frame = 5
	# other falling feedback here
