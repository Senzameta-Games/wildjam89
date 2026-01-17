extends State
class_name AimState

var time_slowed: bool = false
@export var max_aim_dur: float = 0.5
@export_range(0.0, 1.0) var velocity_preserved: float = 0.05
@export var tether_radius: float = 20
@export var cooldown_dur: float = 1.5

var aim_timer: float = 0.0
var aim_pos: Vector2

func enter() -> void:
	# store position on entering
	aim_pos = player.position
	aim_timer = 0.0
	# hold in air briefly
	player.velocity *= velocity_preserved
	player.set_time_scale(0.4)
	time_slowed = true
	# show visuals
	fall_feedback()
	player.aim_visual.visible = true
	player.aim_raycast.enabled = true
	
func exit() -> void:
	# enter cooldown
	player.aim_cooldown = cooldown_dur
	# sanity check
	if time_slowed:
		player.set_time_scale(1.0)
		time_slowed = false
	# hide visuals
	player.aim_visual.visible = false
	player.aim_raycast.enabled = false
	player.velocity = Vector2.ZERO
	
func physics_update(delta: float) -> void:
	aim_timer += delta
	
	if aim_timer >= max_aim_dur:
		transition_requested.emit(self, AirState)
		return
	
	if player.position.distance_to(aim_pos) > tether_radius:
		transition_requested.emit(self, AirState)
	
	var dir = Input.get_axis("move_left", "move_right")
	
	var aim_move_speed: = player.move_speed * 0.3
	
	if dir:
		player.velocity.x = move_toward(player.velocity.x, dir * aim_move_speed, player.move_acceleration * delta)
	else:
		player.velocity.x = move_toward(player.velocity.x, 0, player.move_friction * delta)
	
	player.move_and_slide()
	player.update_facing_dir(dir)
	
	if Input.is_action_just_released("aim"):
		transition_requested.emit(self, AirState)
		return
	
	if Input.is_action_just_pressed("stomp"):
		transition_requested.emit(self, StompState)
	
	if player.is_on_floor():
		transition_requested.emit(self, GroundState)
		
func fall_feedback():
	player.player_sprite.play("jump", 0.6)
