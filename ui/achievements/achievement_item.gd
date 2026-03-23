extends Control
class_name AchievementItem

# Displays a single achievement with its unlock status
# TODO: Support displaying progressive tier achievements with segmented progress indicator

@onready var name_label: Label = $HBoxContainer/MarginContainer/VBoxContainer/NameLabel
@onready var description_label: Label = $HBoxContainer/MarginContainer/VBoxContainer/DescriptionLabel
@onready var status_label: Label = $HBoxContainer/StatusLabel

func display_achievement(achievement: AchievementData, is_unlocked: bool) -> void:
	name_label.text = achievement.achievement_name
	description_label.text = achievement.achievement_description
	
	if is_unlocked:
		status_label.text = "✓"
		status_label.modulate = Color.GREEN
		name_label.modulate = Color.WHITE
		description_label.modulate = Color.WHITE
	else:
		status_label.text = "?"
		status_label.modulate = Color.GRAY
		name_label.modulate = Color.GRAY
		description_label.modulate = Color.GRAY
