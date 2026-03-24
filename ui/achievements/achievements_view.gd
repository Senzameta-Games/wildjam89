extends CanvasLayer

# Achievements View - Shows all achievements (unlocked first, then locked)

@onready var control: Control = $Control
@onready var achievements_container: VBoxContainer = $Control/Panel/VBoxContainer/ScrollContainer/AchievementsContainer
@onready var close_button: Button = $Control/Panel/VBoxContainer/CloseButtonContainer/CloseButton
@onready var scroll_container: ScrollContainer = $Control/Panel/VBoxContainer/ScrollContainer

var achievement_item_scene: PackedScene

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	# Try to load the achievement item scene
	var scene_path = "res://ui/achievements/achievement_item.tscn"
	if ResourceLoader.exists(scene_path):
		achievement_item_scene = load(scene_path) as PackedScene
		if not achievement_item_scene:
			push_error("Failed to load achievement_item.tscn - file exists but couldn't be loaded as PackedScene")
	else:
		push_error("achievement_item.tscn does not exist at path: " + scene_path)
	
	# Connect close button signal
	if close_button:
		close_button.pressed.connect(_on_close_button_pressed)
	
	control.visible = false

func _input(_event: InputEvent) -> void:
	# Handle Esc key to close (same as pause menu does)
	if Input.is_action_just_pressed("pause") and control.visible:
		hide_achievements()
		get_viewport().set_input_as_handled()

func show_achievements() -> void:
	control.visible = true
	populate_achievements()

func hide_achievements() -> void:
	control.visible = false

func populate_achievements() -> void:
	# Clear existing items
	for child in achievements_container.get_children():
		child.queue_free()

	if not achievement_item_scene:
		push_error("Cannot create achievement items: achievement_item_scene is null")
		return

	if not Achievements:
		push_error("Achievements singleton is null!")
		return

	# Sections in display order; skip any with no achievements
	var sections: Array = [
		[AchievementData.AchievementMode.ARCADE,     "Arcade"],
		[AchievementData.AchievementMode.ADVENTURE,  "Adventure"],
		[AchievementData.AchievementMode.SHARED,     "Shared"],
	]

	for section: Array in sections:
		var mode: AchievementData.AchievementMode = section[0]
		var label_text: String = section[1]
		var achievements: Array[AchievementData] = Achievements.get_achievements_for_mode(mode)

		if achievements.is_empty():
			continue

		# Section header
		var header := Label.new()
		header.text = label_text
		achievements_container.add_child(header)

		# Sort: unlocked first, then locked
		achievements.sort_custom(func(a: AchievementData, b: AchievementData) -> bool:
			var a_unlocked: bool = a.achievement_id in Achievements.unlocked_achievements
			var b_unlocked: bool = b.achievement_id in Achievements.unlocked_achievements
			if a_unlocked != b_unlocked:
				return a_unlocked
			return false
		)

		for achievement: AchievementData in achievements:
			var item: Node = achievement_item_scene.instantiate()
			if not item:
				push_error("Failed to instantiate achievement item for: " + achievement.achievement_name)
				continue
			achievements_container.add_child(item)
			var is_unlocked: bool = achievement.achievement_id in Achievements.unlocked_achievements
			item.display_achievement(achievement, is_unlocked)

func _on_close_button_pressed() -> void:
	print("Close button pressed!")
	hide_achievements()
