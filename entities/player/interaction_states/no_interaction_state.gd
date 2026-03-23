class_name NoInteractionState
extends InteractionState

# Default: no interaction active, all movement allowed.
# get_movement_constraint() inherited from base returns permissive defaults.

func enter() -> void:
	player.interact_pressed.connect(_on_interact_pressed)

func exit() -> void:
	if player.interact_pressed.is_connected(_on_interact_pressed):
		player.interact_pressed.disconnect(_on_interact_pressed)

func _on_interact_pressed() -> void:
	var shop = player._find_nearest_shop()
	if shop:
		transition_requested.emit(self, DepositingState)
