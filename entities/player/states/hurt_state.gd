extends State
class_name HurtState

@export var knockback_force: Vector2 = Vector2(80.0, -200.0)
@export var knockback_dur: float = 0.2

var timer: float = 0.0

func enter() -> void:
	# feedback
	player.player_sprite.play("hurt")
	player.sfx_hurt.play()
	player.is_stomping = false
	# reset timer
	timer = knockback_dur
	# get knockback dir
	var dir = sign(player.global_position.x - player.last_damage_pos.x)
	if dir == 0: dir = 1
	# get bumped
	player.velocity = Vector2(dir * knockback_force.x, knockback_force.y)
	
func physics_update(delta: float) -> void:
	player.apply_gravity(delta)
	player.move_and_slide()
	
	timer -= delta
	
	if timer <= 0:
		if player.is_on_floor():
			transition_requested.emit(self, GroundState)
		else:
			transition_requested.emit(self, AirState)
