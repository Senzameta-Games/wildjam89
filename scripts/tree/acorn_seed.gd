extends Node2D
class_name AcornSeed

signal planted(slot_index: int, location: Vector2)

# Config
var gravity: float = 400.0
var terminal_velocity: float = 300.0
var embed_depth: float = 8.0

# State
var velocity_y: float = 0.0
var is_grounded: bool = false
var target_y: float = 0.0
var slot_index: int = -1

# Nodes
@onready var sprite: Sprite2D = $Sprite
@onready var static_collider: CollisionShape2D = $StaticBody/Collider
@onready var land_sfx: AudioStreamPlayer2D = $LandSFX

func _ready() -> void:
	static_collider.set_deferred("disabled", true)
	set_process(false)

func initialize(start_pos: Vector2, ground_level_y: float, _slot_index: int) -> void:
	global_position = start_pos
	target_y = ground_level_y
	slot_index = _slot_index
	set_process(true)

func _process(delta: float) -> void:
	if is_grounded: return

	velocity_y = move_toward(velocity_y, terminal_velocity, gravity * delta)
	position.y += velocity_y * delta
	
	if position.y >= target_y + embed_depth:
		_land()

func _land() -> void:
	is_grounded = true
	position.y = target_y + embed_depth
	
	static_collider.set_deferred("disabled", false)
	
	if land_sfx:
		land_sfx.play()
	
	var tween = create_tween().set_loops()
	tween.tween_interval(2.0) # Pause between shine
	tween.tween_property(sprite, "modulate", Color(3.0, 3.0, 3.0), 0.1).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(sprite, "modulate", Color.WHITE, 0.3).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

func _on_stomp_area_body_entered(body: Node2D) -> void:
	if not is_grounded: return
	
	if body is Player:
		if body.is_stomping or body.velocity.y > 0:
			_be_planted(body)

func _be_planted(player: Player) -> void:
	player.bounce()
	planted.emit(slot_index, Vector2(global_position.x, target_y))
	queue_free()
