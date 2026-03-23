extends Node

const PRIORITY_PAUSE:    int = 100
const PRIORITY_HIT_STOP: int = 50
const PRIORITY_AIM:      int = 10
const PRIORITY_DEFAULT:  int = 0

# Each entry: { id: StringName, scale: float, priority: int }
var _stack: Array[Dictionary] = []

## Push a time scale request. Updates an existing entry if the id is already present.
func push(id: StringName, scale: float, priority: int) -> void:
	for entry in _stack:
		if entry.id == id:
			entry.scale = scale
			entry.priority = priority
			_apply()
			return
	_stack.append({ id = id, scale = scale, priority = priority })
	_apply()

## Remove a time scale request by id.
func pop(id: StringName) -> void:
	for i in _stack.size():
		if _stack[i].id == id:
			_stack.remove_at(i)
			break
	_apply()

## Remove all requests and reset Engine.time_scale to 1.0.
func clear() -> void:
	_stack.clear()
	Engine.time_scale = 1.0

## Returns the current effective time scale.
func get_effective_scale() -> float:
	return Engine.time_scale

func _apply() -> void:
	if _stack.is_empty():
		Engine.time_scale = 1.0
		return
	var best: Dictionary = _stack[0]
	for entry in _stack:
		if entry.priority > best.priority:
			best = entry
	Engine.time_scale = best.scale
