extends Node

# Achievement Manager - Autoload Singleton
# Tracks and unlocks achievements

signal achievement_unlocked(achievement_data: AchievementData)

var unlocked_achievements: Dictionary = {}  # achievement_id -> AchievementData

# Trackers for different achievement types (reset each run)
# Note: Was tracking total_seeds, but realized we're doing it already at Economy.get_balance() (no need to duplicate)
var total_enemies_stomped: int = 0
var total_flowers_planted: int = 0
var recent_stomps: Array[float] = []  # Timestamps of recent stomps for multi-stomp tracking
var total_bombs_blocked: int = 0
var killed_enemy_types: Array[String] = []

# All achievements defined here
var achievement_resources: Dictionary = {}  # achievement_id -> AchievementData

func _ready() -> void:
	load_achievements()
	Economy.seeds_changed.connect(func(_val): on_seed_collected())

func load_achievements() -> void:
	var achievements = [
		{
			"id": "seed_collector_10",
			"name": "Seed Collector",
			"description": "Collect 10 seeds",
			"condition": AchievementData.ConditionType.SEED_COUNT,
			"threshold": 10
		},
		{
			"id": "seed_collector_50",
			"name": "Seed Master",
			"description": "Collect 50 seeds",
			"condition": AchievementData.ConditionType.SEED_COUNT,
			"threshold": 50
		},
		{
			"id": "stomp_master",
			"name": "Stomp Master",
			"description": "Stomp 10 enemies",
			"condition": AchievementData.ConditionType.ENEMIES_STOMPED,
			"threshold": 10
		},
		{
			"id": "multi_stomp",
			"name": "Combo Stomp!",
			"description": "Stomp 3 enemies within 2 seconds",
			"condition": AchievementData.ConditionType.MULTI_STOMP,
			"threshold": 3,
			"time_window": 2.0
		},
		{
			"id": "flower_gardener",
			"name": "Flower Gardener",
			"description": "Plant 5 flowers",
			"condition": AchievementData.ConditionType.FLOWERS_PLANTED,
			"threshold": 5
		},
		{
			"id": "bomb_blocker",
			"name": "Bomb Blocker",
			"description": "Block a bomb from hitting the tree",
			"condition": AchievementData.ConditionType.BOMB_BLOCKED,
			"threshold": 1
		},
		{
			"id": "equal_opportunity_stomper",
			"name": "Equal Opportunity Stomper",
			"description": "Stomp on each type of enemy",
			"condition": AchievementData.ConditionType.EACH_ENEMY_KILLED,
			"threshold": 3
		}
	]
	
	# Create AchievementData resources from the definitions
	for ach_data in achievements:
		var achievement = AchievementData.new()
		achievement.achievement_id = ach_data.id
		achievement.achievement_name = ach_data.name
		achievement.achievement_description = ach_data.description
		achievement.condition_type = ach_data.condition
		achievement.threshold = ach_data.threshold
		if ach_data.has("time_window"):
			achievement.time_window = ach_data.time_window
		
		achievement_resources[ach_data.id] = achievement

func check_achievement(achievement_id: String) -> bool:
	if achievement_id in unlocked_achievements:
		return false  # Already unlocked
	
	if not achievement_id in achievement_resources:
		push_error("Achievement ID not found: " + achievement_id)
		return false
	
	var achievement = achievement_resources[achievement_id]
	return check_condition(achievement)

func check_condition(achievement: AchievementData) -> bool:
	match achievement.condition_type:
		AchievementData.ConditionType.SEED_COUNT:
			return Economy.get_balance() >= achievement.threshold
		
		AchievementData.ConditionType.ENEMIES_STOMPED:
			return total_enemies_stomped >= achievement.threshold
		
		AchievementData.ConditionType.MULTI_STOMP:
			# Check if we have enough stomps within the time window
			var current_time = Time.get_ticks_msec() / 1000.0
			# Remove old stomps outside the time window
			recent_stomps = recent_stomps.filter(func(timestamp): return current_time - timestamp <= achievement.time_window)
			return recent_stomps.size() >= achievement.threshold
		
		AchievementData.ConditionType.FLOWERS_PLANTED:
			return total_flowers_planted >= achievement.threshold
			
		AchievementData.ConditionType.BOMB_BLOCKED:
			return total_bombs_blocked >= achievement.threshold
			
		AchievementData.ConditionType.EACH_ENEMY_KILLED:
			var required_types = ["beetle", "snail", "worm"]
			# Check if we've killed all required enemy types
			return killed_enemy_types.size() >= required_types.size() and \
				required_types.all(func(type): return type in killed_enemy_types)
		
		_:
			return false

func unlock_achievement(achievement_id: String) -> void:
	if achievement_id in unlocked_achievements:
		return  # Already unlocked

	if not achievement_id in achievement_resources:
		push_error("Achievement ID not found: " + achievement_id)
		return

	var achievement = achievement_resources[achievement_id]
	unlocked_achievements[achievement_id] = achievement
	achievement_unlocked.emit(achievement)
	print("Achievement Unlocked: ", achievement.achievement_name)
	Saves.write_meta()

func check_and_unlock_achievement(achievement_id: String) -> void:
	if check_achievement(achievement_id):
		unlock_achievement(achievement_id)

# Public methods to track game events
func on_seed_collected() -> void:
	# Seeds are tracked in Economy.get_balance(), just check achievements
	check_all_achievements()

func on_enemy_stomped(enemy_type: String = "enemy") -> void:
	total_enemies_stomped += 1
	var current_time = Time.get_ticks_msec() / 1000.0
	recent_stomps.append(current_time)
	
	# Track unique enemy types killed
	if enemy_type not in killed_enemy_types:
		killed_enemy_types.append(enemy_type)
	
	check_all_achievements()

func on_flower_planted() -> void:
	total_flowers_planted += 1
	check_all_achievements()
	
func on_bomb_blocked() -> void:
	total_bombs_blocked += 1
	check_all_achievements()

func check_all_achievements() -> void:
	# Check all achievements that aren't already unlocked
	for achievement_id in achievement_resources:
		if not achievement_id in unlocked_achievements:
			check_and_unlock_achievement(achievement_id)

# Reset achievements for a new run
func reset_achievements() -> void:
	unlocked_achievements.clear()
	# Note: Economy balance is reset in Economy.reset()
	total_enemies_stomped = 0
	total_flowers_planted = 0
	recent_stomps.clear()
	total_bombs_blocked = 0
	killed_enemy_types.clear()

func serialize_meta() -> Dictionary:
	return { "unlocked_achievements": unlocked_achievements.keys() }

func deserialize_meta(data: Dictionary) -> void:
	# load_achievements() has already run in _ready(), so achievement_resources is populated
	for id in data.get("unlocked_achievements", []):
		if id in achievement_resources:
			unlocked_achievements[id] = achievement_resources[id]

func serialize_run() -> Dictionary:
	return {
		"total_enemies_stomped": total_enemies_stomped,
		"total_flowers_planted": total_flowers_planted,
		"total_bombs_blocked": total_bombs_blocked,
		"killed_enemy_types": killed_enemy_types.duplicate(),
	}

func deserialize_run(data: Dictionary) -> void:
	total_enemies_stomped = data.get("total_enemies_stomped", 0)
	total_flowers_planted = data.get("total_flowers_planted", 0)
	total_bombs_blocked = data.get("total_bombs_blocked", 0)
	killed_enemy_types.assign(data.get("killed_enemy_types", []))
	recent_stomps.clear()  # intentionally not restored — stale timestamps break multi-stomp window
