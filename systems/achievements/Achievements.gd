extends Node

# Achievement Manager - Autoload Singleton
# Tracks and unlocks achievements

signal achievement_unlocked(achievement_data: AchievementData)

var unlocked_achievements: Dictionary = {}  # achievement_id -> AchievementData

# Lifetime tier progress — persists across runs in meta save.
# achievement_id -> highest completed tier index (-1 = none)
var tier_progress: Dictionary = {}

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
	var dir_path := "res://systems/achievements/definitions/"
	var dir := DirAccess.open(dir_path)
	if not dir:
		push_error("Achievements: Could not open definitions directory: " + dir_path)
		return

	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if file_name.ends_with(".tres"):
			var resource = load(dir_path + file_name)
			if resource is AchievementData:
				achievement_resources[resource.achievement_id] = resource
		file_name = dir.get_next()
	dir.list_dir_end()

	print("Achievements: Loaded %d achievement definitions" % achievement_resources.size())

func check_achievement(achievement_id: String) -> bool:
	if achievement_id in unlocked_achievements:
		return false  # Already fully unlocked

	if not achievement_id in achievement_resources:
		push_error("Achievement ID not found: " + achievement_id)
		return false

	var achievement = achievement_resources[achievement_id]
	return check_condition(achievement)

func check_condition(achievement: AchievementData) -> bool:
	if achievement.tiers.is_empty():
		# One-shot: existing threshold logic unchanged
		return _check_threshold(achievement)
	else:
		# Progressive: check if any new tier was reached
		return _check_tiers(achievement)

func _check_threshold(achievement: AchievementData) -> bool:
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

func _check_tiers(achievement: AchievementData) -> bool:
	var current_tier := tier_progress.get(achievement.achievement_id, -1)
	var current_value := _get_condition_value(achievement)

	# Find the highest tier whose threshold we meet
	var highest_qualifying := -1
	for i in range(achievement.tiers.size()):
		if current_value >= achievement.tiers[i].threshold:
			highest_qualifying = i

	if highest_qualifying > current_tier:
		tier_progress[achievement.achievement_id] = highest_qualifying
		return true  # New tier reached
	return false

## Returns the raw numeric value for a condition type, used by tiered achievement checks.
## NOTE: MULTI_STOMP and EACH_ENEMY_KILLED don't map to a single accumulating integer,
## so they return 0 here. Tiered achievements should only use count-based conditions
## (SEED_COUNT, ENEMIES_STOMPED, FLOWERS_PLANTED, BOMB_BLOCKED).
func _get_condition_value(achievement: AchievementData) -> int:
	match achievement.condition_type:
		AchievementData.ConditionType.SEED_COUNT:
			return Economy.get_balance()
		AchievementData.ConditionType.ENEMIES_STOMPED:
			return total_enemies_stomped
		AchievementData.ConditionType.FLOWERS_PLANTED:
			return total_flowers_planted
		AchievementData.ConditionType.BOMB_BLOCKED:
			return total_bombs_blocked
		_:
			return 0

func unlock_achievement(achievement_id: String) -> void:
	if not achievement_id in achievement_resources:
		push_error("Achievement ID not found: " + achievement_id)
		return

	var achievement = achievement_resources[achievement_id]

	if achievement.tiers.is_empty():
		# One-shot: existing behavior
		if achievement_id in unlocked_achievements:
			return
		unlocked_achievements[achievement_id] = achievement
		achievement_unlocked.emit(achievement)
		print("Achievement Unlocked: ", achievement.achievement_name)
	else:
		# Progressive: emit for each new tier; mark fully unlocked once all tiers done
		var current_tier := tier_progress.get(achievement_id, -1)
		if current_tier >= achievement.tiers.size() - 1:
			# All tiers complete — mark as fully unlocked (idempotent)
			if achievement_id not in unlocked_achievements:
				unlocked_achievements[achievement_id] = achievement
				print("Achievement Fully Complete: ", achievement.achievement_name)
		achievement_unlocked.emit(achievement)
		print("Achievement Tier Reached: ", achievement.achievement_name,
				" — Tier ", current_tier + 1, "/", achievement.tiers.size())

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
	# Check all achievements that aren't already fully unlocked
	for achievement_id in achievement_resources:
		if not achievement_id in unlocked_achievements:
			check_and_unlock_achievement(achievement_id)

# Reset run-scoped trackers; tier_progress is lifetime and is NOT cleared here
func reset_achievements() -> void:
	unlocked_achievements.clear()
	tier_progress.clear()
	# Note: Economy balance is reset in Economy.reset()
	total_enemies_stomped = 0
	total_flowers_planted = 0
	recent_stomps.clear()
	total_bombs_blocked = 0
	killed_enemy_types.clear()

func serialize_meta() -> Dictionary:
	return {
		"unlocked_achievements": unlocked_achievements.keys(),
		"tier_progress": tier_progress.duplicate(),
	}

func deserialize_meta(data: Dictionary) -> void:
	# load_achievements() has already run in _ready(), so achievement_resources is populated
	for id in data.get("unlocked_achievements", []):
		if id in achievement_resources:
			unlocked_achievements[id] = achievement_resources[id]
	tier_progress = data.get("tier_progress", {}).duplicate()

func serialize_run() -> Dictionary:
	return {
		"total_enemies_stomped": total_enemies_stomped,
		"total_flowers_planted": total_flowers_planted,
		"total_bombs_blocked": total_bombs_blocked,
		"killed_enemy_types": killed_enemy_types.duplicate(),
		"tier_progress": tier_progress.duplicate(),
	}

func deserialize_run(data: Dictionary) -> void:
	total_enemies_stomped = data.get("total_enemies_stomped", 0)
	total_flowers_planted = data.get("total_flowers_planted", 0)
	total_bombs_blocked = data.get("total_bombs_blocked", 0)
	killed_enemy_types.assign(data.get("killed_enemy_types", []))
	tier_progress = data.get("tier_progress", {}).duplicate()
	recent_stomps.clear()  # intentionally not restored — stale timestamps break multi-stomp window
