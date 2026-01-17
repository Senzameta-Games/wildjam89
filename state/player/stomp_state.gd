extends State
class_name StompState

func enter():
	player.stomp()
	# TODO player.player_sprite.player("stomp")
	player.player_collider.scale = Vector2(1.8, 1.0)
	player.sfx_stompfall.play()
	player.is_stomping = true
	player.set_collision_mask_value(6, false)

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.move_and_slide()
	
	if player.is_on_floor():
		transition_requested.emit(self, GroundState)
		return

	if player.velocity.y < 0:
		transition_requested.emit(self, AirState)
		
func exit():
	player.set_collision_mask_value(6, true)
