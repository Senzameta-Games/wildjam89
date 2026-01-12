class_name State
extends Node

# Reference to the player (written to by StateMachine)
var player: Player

signal transition_requested(from: State, to_state_type: Script)

# Virtual methods
func enter() -> void:
	pass

func exit() -> void:
	pass

func update(delta: float) -> void:
	pass

func physics_update(delta: float) -> void:
	pass

func handle_input(event: InputEvent) -> void:
	pass
