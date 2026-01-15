extends Resource
class_name AchievementData

@export_category("Identity")
@export var achievement_id: String
@export var achievement_name: String
@export var achievement_description: String

@export_category("Unlock Condition")
@export var condition_type: ConditionType
enum ConditionType {
	SEED_COUNT,         # Unlocks when seed count reaches threshold
	ENEMIES_STOMPED,    # Unlocks when total enemies stomped reaches threshold
	MULTI_STOMP,        # Unlocks when X enemies stomped within time window
	FLOWERS_PLANTED     # Unlocks when total flowers planted reaches threshold
}

@export var threshold: int = 1  # For count-based achievements
@export var time_window: float = 2.0  # For multi-stomp achievements (seconds)
