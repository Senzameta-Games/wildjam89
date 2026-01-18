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
var harmless: bool = false

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
			if not harmless:
				body.hurt(global_position)
				blow_up()
				if Achievements:
					Achievements.on_bomb_blocked()
			
		elif body.is_in_group("level"):
			blow_up()

func blow_up() -> void:
	exploded = true
	
	set_physics_process(false)
	$Collider.set_deferred("disabled", true)
	rotation = 0
	bomb_sprite.play("blow up")
	get_tree().call_group("camera", "apply_shake", Vector2(4, 4), 2.0)
	if blowup_sfx:
		blowup_sfx.play()
		await blowup_sfx.finished
	else:
		await bomb_sprite.animation_finished
	queue_free()


func _on_area_entered(area: Area2D) -> void:
	if exploded:
		return
	if area:
		print(str(area))
		# Check if this area belongs to ANY tree (not a specific target)
		# The area's owner should be the tree node
		var area_owner = area.owner
		if area_owner and area_owner is SeedTree:
			area_owner.hurt(5)
			blow_up()
		elif area.is_in_group("tree"):
			# Fallback: if area itself is in tree group
			if area.owner:
				area.owner.hurt(5)
			blow_up()
