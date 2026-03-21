extends HBoxContainer

@onready var seed_count: Label = find_child("seed_count")
@onready var icon: TextureRect = $TextureRect

var default_pos: Vector2

func _ready() -> void:
	default_pos = position
	seed_count.text = str(Economy.get_balance())
	Economy.seeds_changed.connect(_on_seeds_changed)

func _on_seeds_changed(new_amount: int) -> void:
	seed_count.text = "%03d" % new_amount

func shake_visual() -> void:
	var tween = create_tween()
	tween.tween_property(self, "position:y", default_pos.y + 5, 0.05)
	tween.tween_property(self, "position:y", default_pos.y - 5, 0.05)
	tween.tween_property(self, "position:y", default_pos.y + 5, 0.05)
	tween.tween_property(self, "position:y", default_pos.y, 0.05)
	
	var color_tween = create_tween()
	seed_count.modulate = Color(1, 0.2, 0.2)
	color_tween.tween_property(seed_count, "modulate", Color.WHITE, 0.3)
