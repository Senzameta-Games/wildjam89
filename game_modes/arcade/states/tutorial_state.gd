class_name TutorialState
extends ModeState

func enter() -> void:
	if Tutorial.tutorial_completed:
		transition_requested.emit(self, PlayState)
		return
	Tutorial.tutorial_phase_completed.connect(_on_phase_completed)

func exit() -> void:
	if Tutorial.tutorial_phase_completed.is_connected(_on_phase_completed):
		Tutorial.tutorial_phase_completed.disconnect(_on_phase_completed)

func _on_phase_completed(phase: String) -> void:
	if phase == "complete":
		transition_requested.emit(self, PlayState)
