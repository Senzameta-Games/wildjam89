extends State
class_name GroundState

@export var step_interval: float = 0.3
var step_timer: float = 0.0

var is_recovering: bool = false

func enter() -> void:
	player.player_collider.scale = Vector2(1.0, 1.0)
	player.aim_cooldown = 0.0
	player.can_aim = false
	player.velocity.y = 0
	player.jumps_available = 2 if Game.has_ability("double_jump") else 1
	player.bounce_recovering = false
	step_timer = 0.0
	
	is_recovering = false
	
	if player.is_stomping:
		stomp_feedback()
	else:
		land_feedback()

func stomp_feedback():
	is_recovering = true
	player.velocity = Vector2.ZERO
	player.player_sprite.stop()
	player.player_sprite.play("stomp")
	player.player_sprite.frame = 2
	player.sfx_land.volume_db = -2.0
	player.sfx_land.pitch_scale = 1.0
	player.sfx_land.play()
	get_tree().call_group("camera", "apply_shake", Vector2(0, 12), 7.0)
	
	await player.player_sprite.animation_finished
	is_recovering = false
	player.is_stomping = false
	player.player_sprite.play("idle")
	
func land_feedback():
	player.sfx_land.play()
	
func physics_update(delta: float) -> void:
	if is_recovering:
		player.move_and_slide()
		return
	# inputs
	var dir = Input.get_axis("move_left", "move_right")

	# feedback
	if dir != 0:
		player.player_sprite.play("run")
		step_timer -= delta
		if step_timer <= 0:
			player.sfx_step.play()
			step_timer = step_interval
	else:
		player.player_sprite.play("idle")
		step_timer = 0.0
	
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
	
	if Input.is_action_just_pressed("stomp"):
		if player.is_on_floor():
			for i in player.get_slide_collision_count():
				var collision = player.get_slide_collision(i)
				var collider = collision.get_collider()
				# Check if it's a one-way platform (layer 6)
				if collider and collider.get_collision_layer_value(6):
					player.set_collision_mask_value(6, false)
					player.global_position.y += 1 
					break
		transition_requested.emit(self, StompState)
		return
