class_name GameState
extends Node

var context: Node
signal transition_requested(from: GameState, to_state_type: Script)

func enter() -> void:
	pass

func exit() -> void:
	pass

func update(_delta: float) -> void:
	pass

func physics_update(_delta: float) -> void:
	pass
