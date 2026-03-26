extends State
class_name StompState

func enter():
	player.stomp()
	player.player_sprite.play("stomp")
	player.player_sprite.frame = 1
	player.player_sprite.pause()
	player.sfx_stompfall.play()
	player.is_stomping = true
	player.set_collision_mask_value(6, false)

func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.move_and_slide()

	if player.is_on_floor():
		transition_requested.emit(self, GroundState)
		return

func exit():
	player.player_collider.scale = Vector2.ONE
	player.set_collision_mask_value(6, true)
