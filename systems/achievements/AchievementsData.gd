extends Resource
class_name AchievementData

@export_category("Mode")
## Which game mode this achievement belongs to.
## Default is ARCADE so existing .tres files require no manual edits —
## Achievements._load_definitions() sets this from the subdirectory at load time.
enum AchievementMode { ARCADE, ADVENTURE, SHARED }
@export var mode: AchievementMode = AchievementMode.ARCADE

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
	FLOWERS_PLANTED,    # Unlocks when total flowers planted reaches threshold
	BOMB_BLOCKED,		# Unlocks when blocking a bomb that beetles throw
	EACH_ENEMY_KILLED	# Unlocks when each enemy type killed
}

@export var threshold: int = 1  # For count-based achievements
@export var time_window: float = 2.0  # For multi-stomp achievements (seconds)

@export_category("Progressive Tiers")
## If populated, this is a progressive achievement. The top-level threshold is ignored;
## each tier defines its own threshold. Tiers should be ordered lowest → highest.
@export var tiers: Array[AchievementTier] = []
