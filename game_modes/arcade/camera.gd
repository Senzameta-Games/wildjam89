extends Camera2D

@export var default_fade: float = 0.0
@export var default_amp: Vector2 = Vector2(0.0, 0.0)

var current_fade: float = 0.0
var current_amp: Vector2 = Vector2.ZERO
var shake_strength: float = 0.0

func _ready() -> void:
	pass
	
func _process(delta: float) -> void:
	if shake_strength > 0:
		shake_strength = move_toward(shake_strength, 0.0, current_fade * delta)
		
		offset = Vector2(
			randf_range(-shake_strength, shake_strength),
			randf_range(-shake_strength, shake_strength)
		)
		if is_equal_approx(shake_strength, 0.0):
			shake_strength = 0.0
			offset = Vector2.ZERO

func apply_shake(amplitude: Vector2, fade: float) -> void:
	current_amp = amplitude
	current_fade = fade
	shake_strength = 1.0
