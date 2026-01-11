extends Resource
class_name TreeData

@export_category("ID")
@export var tree_name: String
@export var tree_type: int
# ^ would be used in an array somewhere, which also needs to be made
@export_category("Gameplay")
@export var tree_current_health: int
@export var tree_max_health: int
