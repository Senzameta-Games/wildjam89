extends State
class_name AirState

@export var coyote_time: float = 0.1
var coyote_timer: float = 0.0

func enter() -> void:
	if player.is_stomping:
		player.is_stomping = false
	
	# If bounce recovering, let the stomp animation continue playing
	if player.bounce_recovering:
		coyote_timer = 0.0
		return
	
	if player.velocity.y < 0:
		jump_feedback()
		coyote_timer = 0.0
	else:
		fall_feedback()
		coyote_timer = coyote_time
		player.jumps_available -= 1
	
func physics_update(delta: float) -> void:
	var dir = Input.get_axis("move_left", "move_right")
	
	if player.position.y <= 260.0:
		player.can_aim = true
	
	if coyote_timer > 0:
		coyote_timer -= delta
	
	# Handle bounce recovery animation
	if player.bounce_recovering:
		# Check if stomp animation finished or player is providing input
		var anim_finished = not player.player_sprite.is_playing() or player.player_sprite.animation != "stomp"
		var has_input = abs(dir) > 0.1
		
		if anim_finished or has_input:
			player.bounce_recovering = false
			# Transition to appropriate air animation
			if player.velocity.y < 0:
				jump_feedback()
			else:
				fall_feedback()
	
	if Input.is_action_just_pressed("jump") and coyote_timer > 0:
		player.jump()
		jump_feedback()
		coyote_timer = 0.0
		return
	elif Input.is_action_just_pressed("jump") and player.jumps_available > 0:
		player.jump()
		jump_feedback()
		return
	
	if Input.is_action_pressed("aim") and player.aim_cooldown <= 0 and Game.has_ability("aim_stomp"):
		transition_requested.emit(self, AimState)
		return
	
	if Input.is_action_just_pressed("stomp"):
		transition_requested.emit(self, StompState)
		return
	
	player.apply_gravity(delta)
	player.move(dir, delta)
	player.move_and_slide()
	player.update_facing_dir(dir)
	
	if player.is_on_floor():
		transition_requested.emit(self, GroundState)
		return
	
func jump_feedback():
	player.player_sprite.play("jump")
	player.sfx_jump.play()
	if Game.has_ability("double_jump") and player.jumps_available == 1:
		player.sfx_dash.play()
	# other jumping feedback here

func fall_feedback():
	player.player_sprite.play("jump", 0.5, true)
	# other falling feedback here
