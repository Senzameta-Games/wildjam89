extends Node

var tutorial_completed: bool = false

func serialize_meta() -> Dictionary:
	return { "tutorial_completed": tutorial_completed }

func deserialize_meta(data: Dictionary) -> void:
	tutorial_completed = data.get("tutorial_completed", false)

func reset_tutorial() -> void:
	tutorial_completed = false
