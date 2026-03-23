class_name InteractionStateMachine
extends Node

@export var initial_state: InteractionState
@export var debug_transitions: bool = false

var current_state: InteractionState
var _states: Dictionary = {} # Key: Script (Resource), Value: InteractionState (Node)

func _ready() -> void:
	# Wait for the player to be ready before initialising states.
	await owner.ready

	for child in get_children():
		if child is InteractionState:
			_states[child.get_script()] = child
			child.player = owner
			child.transition_requested.connect(_on_transition_requested)

	if initial_state:
		_transition_to(initial_state)

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)

## Returns the movement constraint dict from the active interaction state.
func get_movement_constraint() -> Dictionary:
	if current_state:
		return current_state.get_movement_constraint()
	return {
		"allow_movement": true,
		"speed_multiplier": 1.0,
		"allow_jump": true,
		"allow_stomp": true,
		"allow_aim": true,
	}

func _on_transition_requested(from: InteractionState, to_state_type: Script) -> void:
	if from != current_state:
		return

	var new_state: InteractionState = _states.get(to_state_type)
	if not new_state:
		push_warning("InteractionStateMachine: No state found for %s" % to_state_type)
		return

	_transition_to(new_state)

func _transition_to(new_state: InteractionState) -> void:
	if current_state:
		current_state.exit()

	if debug_transitions:
		print("InteractionSM: %s -> %s" % [
			current_state.name if current_state else &"None",
			new_state.name,
		])

	current_state = new_state
	current_state.enter()
