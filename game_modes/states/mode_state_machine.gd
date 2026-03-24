class_name ModeStateMachine
extends Node

@export var initial_state: ModeState
@export var debug_transitions: bool = false

var current_state: ModeState
var _states: Dictionary = {}

func _ready() -> void:
	await owner.ready

	for child in get_children():
		if child is ModeState:
			_states[child.get_script()] = child
			child.context = owner
			child.transition_requested.connect(_on_transition_requested)

	if initial_state:
		_transition_to(initial_state)

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func _on_transition_requested(from: ModeState, to_state_type: Script) -> void:
	if from != current_state:
		return

	var new_state: ModeState = _states.get(to_state_type)
	if not new_state:
		push_warning("ModeStateMachine: No state found for %s" % to_state_type)
		return

	# Defer so transitions triggered during physics (e.g. body_entered) don't
	# try to add/remove nodes while the physics server is flushing queries.
	_transition_to.call_deferred(new_state)

func _transition_to(new_state: ModeState) -> void:
	if current_state:
		current_state.exit()

	if debug_transitions:
		print("Transition: %s -> %s" % [current_state.name if current_state else &"None", new_state.name])

	current_state = new_state
	current_state.enter()
