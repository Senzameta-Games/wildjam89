extends Node2D
class_name Flower

@export var flower_variants: Array[Texture2D] = []

@onready var sprite: Sprite2D = $Sprite

# color names to flower_variants array
const COLOR_NAMES: Array[String] = ["blue", "green", "red"]
var flower_color: String = ""

func _ready() -> void:
	# pick random variant and track its color
	var color_index = randi() % flower_variants.size()
	sprite.texture = flower_variants[color_index]

	# store and add color
	if color_index < COLOR_NAMES.size():
		flower_color = COLOR_NAMES[color_index]
	else:
		flower_color = "green" # fallback

	FlowerManager.add_flower(flower_color)

func reset() -> void:
	FlowerManager.remove_flower(flower_color)
	queue_free()
