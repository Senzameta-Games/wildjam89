class_name InteractionState
extends Node

var player: Player

signal transition_requested(from: InteractionState, to_state_type: Script)

## Return movement constraints for this interaction state.
## Override in subclasses to restrict movement.
func get_movement_constraint() -> Dictionary:
	return {
		"allow_movement": true,
		"speed_multiplier": 1.0,
		"allow_jump": true,
		"allow_stomp": true,
		"allow_aim": true,
	}

func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass

func handle_input(_event: InputEvent) -> void:
	pass
