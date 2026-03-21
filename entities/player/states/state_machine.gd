class_name StateMachine
extends Node

@export var initial_state: State
@export var debug_transitions: bool = false

var current_state: State
var _states: Dictionary = {} # Key: Script (Resource), Value: State (Node)

func _ready() -> void:
	# wait for the player
	await owner.ready
	
	# find all child states
	for child in get_children():
		if child is State:
			# pull in the state using its Script resource as the key
			_states[child.get_script()] = child
			
			# assign the state's owner (the player)
			child.player = owner
			
			# connect signal
			child.transition_requested.connect(_on_transition_requested)
	
	# enter the initial state
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

func _on_transition_requested(from: State, to_state_type: Script) -> void:
	if from != current_state:
		return
	
	var new_state: State = _states.get(to_state_type)
	if not new_state:
		push_warning("StateMachine: No state found for %s" % to_state_type)
		return
		
	_transition_to(new_state)

func _transition_to(new_state: State) -> void:
	if current_state:
		current_state.exit()
		
	if debug_transitions:
		print("Transition: %s -> %s" % [current_state.name if current_state else &"None", new_state.name])
		
	current_state = new_state
	current_state.enter()
