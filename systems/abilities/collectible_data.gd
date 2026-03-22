extends Resource
class_name CollectibleData

enum GrantType {
	ABILITY,
	WIN_ITEM,
}

@export_category("Identity")
@export var collectible_key: String
@export var display_name: String
@export_multiline var description: String
@export_multiline var flavor_text: String

@export_category("Presentation")
@export var icon: Texture2D
@export var pickup_scene: PackedScene

@export_category("Grant")
@export var grant_type: GrantType = GrantType.ABILITY
