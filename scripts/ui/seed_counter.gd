extends Node

@onready var seed_count: Label = find_child("seed_count")

func _ready() -> void:
	seed_count.text = str(Game.total_seeds)
	
	Game.seeds_changed.connect(_on_seeds_changed)

func _on_seeds_changed(new_amount: int) -> void:
	seed_count.text = str(new_amount)
