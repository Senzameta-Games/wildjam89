extends Area2D
class_name Bomb

@export var speed: float
@export var damage: int
@export var blast_radius: float
@export var bomb_sprite: AnimatedSprite2D
@onready var blowup_sfx: AudioStreamPlayer2D = $BlowUp

@onready var fuzzy_speed: float = randf_range((speed * 0.9), (speed * 1.2))
var velocity: Vector2
var grav: float = (Game.gravity / 2)

var exploded: bool = false

func setup(dir: float, arc: float) -> void:
	# arc it
	velocity.x = dir * fuzzy_speed
	velocity.y = arc

func _physics_process(delta: float) -> void:
	# fake gravity
	velocity.y += grav * delta
	position += velocity * delta
	rotation = velocity.angle()
	
func _on_body_entered(body: Node2D) -> void:
	if exploded:
		return
	if body:
		print(str(body))
		if body.is_in_group("player"):
			body.hurt(global_position)
			blow_up()
			if Achievements:
				Achievements.on_bomb_blocked()
			#print("bomb hit something with method hurt() and blew up")
			
		elif body.is_in_group("level"):
			blow_up()
			#print("bomb hit level and blew up")

func blow_up() -> void:
	exploded = true
	
	set_physics_process(false)
	$Collider.set_deferred("disabled", true)
	rotation = 0
	bomb_sprite.play("blow up")
	get_tree().call_group("camera", "apply_shake", Vector2(8, 8), 1.0)
	if blowup_sfx:
		blowup_sfx.play()
		await blowup_sfx.finished
	else:
		await bomb_sprite.animation_finished
	queue_free()


func _on_area_entered(area):
	if area:
		print(str(area))
		if area.is_in_group("tree"):
			area.owner.hurt(5)
			blow_up()
