extends Resource
class_name AbilityData

@export_category("Identity")
@export var ability_key: String

@export_category("Gameplay")
@export var duration: float = -1.0  ## Seconds active. -1 = permanent (never expires).

@export_category("UI")
@export var input_hint: String = ""
