class_name PlayState
extends ModeState

func physics_update(_delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		transition_requested.emit(self, PausedState)

func enter() -> void:
	context.stage_won.connect(_on_stage_won)
	context.game_won.connect(_on_game_won)

func exit() -> void:
	if context.stage_won.is_connected(_on_stage_won):
		context.stage_won.disconnect(_on_stage_won)
	if context.game_won.is_connected(_on_game_won):
		context.game_won.disconnect(_on_game_won)

func _on_stage_won(_reward_key: String) -> void:
	transition_requested.emit(self, StageWinState)

func _on_game_won() -> void:
	transition_requested.emit(self, GameWinState)
