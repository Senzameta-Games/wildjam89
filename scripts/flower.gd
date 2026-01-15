extends Node2D
class_name Flower

@export var flower_variants: Array[Texture2D] = []

@onready var sprite: Sprite2D = $Sprite

func _ready() -> void:
	sprite.texture = flower_variants.pick_random()
