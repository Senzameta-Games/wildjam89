extends State
class_name GroundState

@export var step_interval: float = 0.4
var step_timer: float = 0.0

func enter() -> void:
	player.aim_cooldown = 0.0
	player.can_aim = false
	player.velocity.y = 0
	player.jumps_available = 2 if Game.has_ability("double_jump") else 1
	step_timer = 0.0
	
	if player.is_stomping:
		stomp_feedback()
	else:
		land_feedback()

func stomp_feedback():
	player.player_sprite.play("idle")
	player.sfx_land.play()
	get_tree().call_group("camera", "apply_shake", Vector2(0, 8), 12.0)
	
func land_feedback():
	player.sfx_land.play()
	
func physics_update(delta: float) -> void:
	# inputs
	var dir = Input.get_axis("move_left", "move_right")
	
	# let stomp finish
	if player.is_stomping:
		player.is_stomping = false
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
