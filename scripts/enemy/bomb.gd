extends Area2D
class_name Bomb

@export var speed: float
@export var damage: int
@export var blast_radius: float
@export var bomb_sprite: AnimatedSprite2D

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
		if body.has_method("hurt"):
			body.hurt()
		blow_up()
		print("bomb hit something with method hurt() and blew up")
		
	elif body.is_in_group("level"):
		blow_up()
		print("bomb hit level and blew up")

func blow_up() -> void:
	exploded = true
	
	set_physics_process(false)
	rotation = 0
	bomb_sprite.play("blow up")
	await bomb_sprite.animation_finished
	queue_free()
	# TODO: blow up sound
