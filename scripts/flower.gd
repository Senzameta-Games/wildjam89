extends Node2D
class_name Flower

func _ready() -> void:
	if randf() > 0.5:
		scale.x = -scale.x
		
