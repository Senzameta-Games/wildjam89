extends Resource
class_name TreeData

@export_category("Identity")
@export var tree_name: String

@export_category("Growth")
@export var max_sections: int = 20
@export var trunk_section_height: int = 16
@export var base_passive_growth: float = 0.08
@export var max_passive_growth: float = 2.0
@export var active_growth_amount: float = 0.75
