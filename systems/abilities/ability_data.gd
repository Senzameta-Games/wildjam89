extends Resource
class_name AbilityData

@export_category("Identity")
@export var ability_key: String

@export_category("Gameplay")
@export var base_duration: float = 15.0
@export var is_timed: bool = true

@export_category("UI")
@export var input_hint: String = ""
