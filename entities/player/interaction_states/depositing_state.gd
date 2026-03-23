class_name DepositingState
extends InteractionState

var _target_shop: Node2D = null

func get_movement_constraint() -> Dictionary:
	return {
		"allow_movement": true,
		"speed_multiplier": 1.0,
		"allow_jump": true,
		"allow_stomp": true,
		"allow_aim": true,
	}

func enter() -> void:
	_target_shop = player._find_nearest_shop()
	player.interact_released.connect(_on_interact_released)

func exit() -> void:
	if player.interact_released.is_connected(_on_interact_released):
		player.interact_released.disconnect(_on_interact_released)
	if _target_shop and is_instance_valid(_target_shop):
		_target_shop.release_deposit()
	_target_shop = null

func _on_interact_released() -> void:
	transition_requested.emit(self, NoInteractionState)

func physics_update(delta: float) -> void:
	if not _target_shop or not is_instance_valid(_target_shop):
		transition_requested.emit(self, NoInteractionState)
		return
	_target_shop.deposit_tick(delta, player.global_position)
