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

@export_category("Growth Model (Future)")
@export var trunk_taper_curve: Curve          ## How trunk width varies from base to top. Not yet used.
@export var limb_maturity_threshold: float = 0.5  ## 0–1; when a limb becomes a platform. Not yet used.
@export var canopy_growth_curve: Curve        ## Canopy visual scaling. Not yet used.
