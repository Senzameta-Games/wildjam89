## Achievements — Global achievement tracker (arcade and adventure).
## All existing condition checks (SEED_COUNT, ENEMIES_STOMPED, etc.) are wired to
## arcade systems (Economy, Session). In Adventure mode, Economy is never modified
## so seed-based achievements are dormant there.
## Definitions are organised by subdirectory under definitions/:
##   arcade/    — arcade-only achievements (all current definitions)
##   adventure/ — adventure-only achievements (placeholder, none yet)
##   shared/    — achievements that can fire in either mode (placeholder, none yet)
## check_all_achievements() is global — it runs across all modes regardless of the
## current game mode. Mode filtering is for UI display only.
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
	_load_definitions()
	# Arcade-only: Economy.seeds_changed never fires in Adventure (Economy stays at 0).
	# TODO: connect GameState.resource_changed for Adventure seed achievements.
	Economy.seeds_changed.connect(func(_val): on_seed_collected())

## Scan all three mode subdirectories and tag each resource with its mode.
## Silently skips missing directories (adventure/ and shared/ are placeholders).
func _load_definitions() -> void:
	var subdirs: Dictionary = {
		"arcade": AchievementData.AchievementMode.ARCADE,
		"adventure": AchievementData.AchievementMode.ADVENTURE,
		"shared": AchievementData.AchievementMode.SHARED,
	}
	var base_path := "res://systems/achievements/definitions/"
	for subdir: String in subdirs:
		var dir_path := base_path + subdir + "/"
		var dir := DirAccess.open(dir_path)
		if not dir:
			continue  # placeholder directory with no .tres files yet
		dir.list_dir_begin()
		var file_name := dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var resource = load(dir_path + file_name)
				if resource is AchievementData:
					resource.mode = subdirs[subdir]
					achievement_resources[resource.achievement_id] = resource
			file_name = dir.get_next()
		dir.list_dir_end()
	print("Achievements: Loaded %d achievement definitions" % achievement_resources.size())

## Kept for compatibility — internal callers now use _load_definitions().
func load_achievements() -> void:
	_load_definitions()

## Returns all achievements for the given mode, in insertion order.
func get_achievements_for_mode(mode: AchievementData.AchievementMode) -> Array[AchievementData]:
	var result: Array[AchievementData] = []
	for achievement: AchievementData in achievement_resources.values():
		if achievement.mode == mode:
			result.append(achievement)
	return result

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
	var current_tier = tier_progress.get(achievement.achievement_id, -1)
	var current_value = _get_condition_value(achievement)

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
		var current_tier = tier_progress.get(achievement_id, -1)
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

## Checks all achievements regardless of mode. Mode filtering is for UI only.
func check_all_achievements() -> void:
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

# -- Serialization --

## Achievement IDs are unique across all modes, so a flat ID list is sufficient.
## No structural change needed when new modes are added.
func serialize_meta() -> Dictionary:
	return {
		"unlocked_achievements": unlocked_achievements.keys(),
		"tier_progress": tier_progress.duplicate(),
	}

func deserialize_meta(data: Dictionary) -> void:
	# _load_definitions() has already run in _ready(), so achievement_resources is populated
	for id in data.get("unlocked_achievements", []):
		if id in achievement_resources:
			unlocked_achievements[id] = achievement_resources[id]
	tier_progress = data.get("tier_progress", {}).duplicate()

## Arcade-only: captures run-scoped counters for mid-run save/restore.
func serialize_run() -> Dictionary:
	return {
		"total_enemies_stomped": total_enemies_stomped,
		"total_flowers_planted": total_flowers_planted,
		"total_bombs_blocked": total_bombs_blocked,
		"killed_enemy_types": killed_enemy_types.duplicate(),
		"tier_progress": tier_progress.duplicate(),
	}

## Arcade-only: restores run-scoped counters from a mid-run save.
func deserialize_run(data: Dictionary) -> void:
	total_enemies_stomped = data.get("total_enemies_stomped", 0)
	total_flowers_planted = data.get("total_flowers_planted", 0)
	total_bombs_blocked = data.get("total_bombs_blocked", 0)
	killed_enemy_types.assign(data.get("killed_enemy_types", []))
	tier_progress = data.get("tier_progress", {}).duplicate()
	recent_stomps.clear()  # intentionally not restored — stale timestamps break multi-stomp window

## Adventure achievement state that should persist across grove/run sessions.
## Stub — no adventure achievements exist yet.
func serialize_adventure() -> Dictionary:
	# TODO: Adventure achievement state to persist across grove/run sessions
	return {}

## Restore adventure achievement state from a game save.
## Stub — no adventure achievements exist yet.
func deserialize_adventure(_data: Dictionary) -> void:
	# TODO: restore adventure achievement state
	pass
