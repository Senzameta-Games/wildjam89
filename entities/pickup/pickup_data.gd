extends Resource
class_name PickupData

enum GrantType {
	ABILITY,
	WIN_ITEM,
	CURRENCY,
	KEY_ITEM,
}

enum PersistenceScope {
	STAGE,
	RUN,
}

enum ConsumeMode {
	PASSIVE,   # Auto-consumed when the right context is reached (e.g., locked door)
	ACTIVE,    # Player selects from inventory to use
}

@export_category("Identity")
@export var pickup_key: String
@export var display_name: String
@export_multiline var description: String
@export_multiline var flavor_text: String

@export_category("Presentation")
@export var icon: Texture2D
@export var pickup_scene: PackedScene

@export_category("Grant")
@export var grant_type: GrantType = GrantType.ABILITY

@export_category("Currency")
@export var currency_amount: int = 1

@export_category("Key Item")
@export var persistence_scope: PersistenceScope = PersistenceScope.RUN
@export var consume_mode: ConsumeMode = ConsumeMode.PASSIVE
