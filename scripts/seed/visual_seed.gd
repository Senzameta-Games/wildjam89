extends Node2D

var target: Node2D
var speed: float = 400.0
var velocity: Vector2 = Vector2.ZERO

var can_seek: bool = false
var is_collected: bool = false
var is_lost: bool = false
var is_depositing: bool = false

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var collect_sfx: AudioStreamPlayer2D = $SFX/Collected

func _ready() -> void:
	if sprite:
		sprite.play("appear")

func setup(new_target: Node2D) -> void:
	target = new_target
	
	# go up first
	velocity = Vector2(randf_range(-150, 150), randf_range(-250, -100))
	
	# hold so player can read for a moment
	await get_tree().create_timer(0.35).timeout
	can_seek = true

func setup_loss() -> void:
	is_lost = true
	velocity = Vector2(randf_range(-4, 4), randf_range(-400, -200))
	
	var tween = create_tween()
	tween.tween_interval(0.5)
	tween.tween_property(self, "modulate:a", 0.0, 0.2)
	tween.tween_callback(queue_free)

func setup_deposit(new_target: Node2D) -> void:
	is_depositing = true
	target = new_target
	
	velocity = Vector2(randf_range(-32, 32), randf_range(-400, -200))
	
	if collect_sfx: 
		collect_sfx.pitch_scale = 0.5
		collect_sfx.play()
	
	await get_tree().create_timer(0.15).timeout
	can_seek = true

func _process(delta: float) -> void:
	if is_lost:
		velocity += Vector2(0, Game.gravity) * delta
		global_position += velocity * delta
		rotation += (velocity.x * 0.05) * delta
		return

	if not target: return
	if can_seek:
		var direction = global_position.direction_to(target.global_position)
		var target_velocity = direction * speed
		# curve towards the player
		var curve_toward_player = (target_velocity - velocity) * delta * 5.0
		velocity += curve_toward_player
	else:
		# gravity after go up
		velocity = velocity.move_toward(Vector2.ZERO, 5.0)
	# move
	global_position += velocity * delta
	rotation += (velocity.x * 0.05) * delta
	# collect when close enough to player
	if global_position.distance_to(target.global_position) < 20.0:
		_collect()

func _collect() -> void:
	if is_collected: return
	is_collected = true
	if not is_depositing:
		Game.add_seeds(1)
	if sprite:
		sprite.play("appear")
	if not is_depositing and collect_sfx:
		collect_sfx.pitch_scale = 1.0
		collect_sfx.play()
		await collect_sfx.finished
	
	await get_tree().create_timer(0.2).timeout
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	await tween.finished
	queue_free()

	
