extends HBoxContainer

@export var ability_icons: Dictionary = {}
@export var icon_size: Vector2 = Vector2(32, 32)

func _ready() -> void:
	for child in get_children():
		child.queue_free()
	
	for key in Game.unlocked_abilities:
		if Game.unlocked_abilities[key] == true:
			add_icon(key)
	
	Game.ability_unlocked.connect(add_icon)

func add_icon(ability_key: String) -> void:
	if not ability_icons.has(ability_key): return
	
	var texture_rect = TextureRect.new()
	texture_rect.texture = ability_icons[ability_key]
	texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	texture_rect.custom_minimum_size = icon_size
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	
	add_child(texture_rect)
	
