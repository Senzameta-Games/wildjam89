extends Node

var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity")

# PASS-THROUGH: migrate callers to Session directly
signal game_over_called
signal game_won
# PASS-THROUGH: migrate callers to Abilities directly
signal ability_unlocked(ability_name: String)

var game_has_started: bool:
	get: return Session.game_has_started
	set(v): Session.game_has_started = v

var current_stage: int:
	get: return Session.current_stage
	set(v): Session.current_stage = v

var trees_grown_count: int:
	get: return Session.trees_grown_count
	set(v): Session.trees_grown_count = v

func start_new_run() -> void:
	Session.start_new_run()

func next_stage() -> void:
	Session.next_stage()

func stage_reset() -> void:
	Session.stage_reset()
	FlowerManager.reset_flowers()

func get_stage_params() -> Dictionary:
	return Session.get_stage_params()

func check_win_con() -> bool:
	return Session.check_win_con()

func register_tree_grown() -> void:
	Session.register_tree_grown()

func win_game() -> void:
	Session.win_game()

func start_session_timer() -> void:
	Session.start_session_timer()

func stop_session_timer() -> void:
	Session.stop_session_timer()

func get_session_time_formatted() -> String:
	return Session.get_session_time_formatted()

# PASS-THROUGH: migrate callers to Abilities directly
func unlock_ability(ability_key: String) -> void:
	Abilities.unlock_ability(ability_key)

func lock_ability(ability_key: String) -> void:
	Abilities.lock_ability(ability_key)

func has_ability(ability_key: String) -> bool:
	return Abilities.has_ability(ability_key)

func has_seen_ability(ability_key: String) -> bool:
	return Abilities.has_seen_ability(ability_key)

func mark_ability_seen(ability_key: String) -> void:
	Abilities.mark_ability_seen(ability_key)

# PASS-THROUGH: migrate callers to Economy directly
signal seeds_changed(current_total: int)

var total_seeds: int:
	get: return Economy.get_balance()
	set(v): Economy.add_seeds(v - Economy.get_balance())

func add_seeds(amount: int) -> void:
	Economy.add_seeds(amount)

func _ready() -> void:
	Economy.seeds_changed.connect(func(val): seeds_changed.emit(val))
	Abilities.ability_unlocked.connect(func(name): ability_unlocked.emit(name))
	Session.game_over_called.connect(func(): game_over_called.emit())
	Session.game_won.connect(func(): game_won.emit())

func reset_game_state() -> void:
	Economy.reset()
	Session.reset()
	FlowerManager.reset_flowers()
	if Achievements:
		Achievements.reset_achievements()

func _unhandled_input(event):
	if not OS.has_feature("editor"): return

	if event:
		if Input.is_action_just_pressed("stopwatch_get"):
			unlock_ability("aim_stomp")
		if Input.is_action_just_pressed("feather_get"):
			unlock_ability("double_jump")
		if Input.is_action_just_pressed("zapper_get"):
			unlock_ability("pesticide")
		if Input.is_action_just_pressed("big_money"):
			Economy.big_money()
