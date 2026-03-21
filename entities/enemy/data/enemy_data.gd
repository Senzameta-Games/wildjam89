extends Resource
class_name EnemyData

@export_category("ID")
@export var enemy_name: String
@export var enemy_type: int 
# ^ need an array for this. 0 = ground 1 = flying
@export var enemy_unit: int
# ^ need an array for this. 0 = small 1 = medium 2 = large

@export_category("Gameplay")
@export var energy_dropped: int
