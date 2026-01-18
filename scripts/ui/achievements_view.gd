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
	var scene_path = "res://scenes/ui/achievement_item.tscn"
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

func _input(event: InputEvent) -> void:
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
	
	# Check if achievement_item_scene is loaded
	if not achievement_item_scene:
		push_error("Cannot create achievement items: achievement_item_scene is null")
		print("ERROR: achievement_item_scene is null - check if achievement_item.tscn exists and is valid")
		return
	
	# Get all achievements and sort: unlocked first, then locked
	var all_achievements: Array[AchievementData] = []
	var unlocked_achievement_ids: Array[String] = []
	
	# Collect all achievements and track unlocked ones
	if not Achievements:
		push_error("Achievements singleton is null!")
		print("ERROR: Achievements singleton not found")
		return
	
	if Achievements.achievement_resources.is_empty():
		push_error("No achievements found in Achievements.achievement_resources!")
		print("ERROR: Achievements.achievement_resources is empty")
		return
	
	print("Found ", Achievements.achievement_resources.size(), " achievements to display")
	
	for achievement_id in Achievements.achievement_resources:
		var achievement = Achievements.achievement_resources[achievement_id]
		all_achievements.append(achievement)
		if achievement_id in Achievements.unlocked_achievements:
			unlocked_achievement_ids.append(achievement_id)
	
	print("Total achievements: ", all_achievements.size(), ", Unlocked: ", unlocked_achievement_ids.size())
	
	# Sort: unlocked first, then locked (maintain original order within each group)
	all_achievements.sort_custom(func(a: AchievementData, b: AchievementData) -> bool:
		var a_unlocked = a.achievement_id in unlocked_achievement_ids
		var b_unlocked = b.achievement_id in unlocked_achievement_ids
		
		if a_unlocked != b_unlocked:
			return a_unlocked  # Unlocked achievements come first
		return false  # Maintain original order within same group
	)
	
	# Create UI items for each achievement
	for achievement in all_achievements:
		var item = achievement_item_scene.instantiate()
		if not item:
			push_error("Failed to instantiate achievement item for: " + achievement.achievement_name)
			continue
		achievements_container.add_child(item)
		var is_unlocked = achievement.achievement_id in unlocked_achievement_ids
		item.display_achievement(achievement, is_unlocked)
		print("Created achievement item for: ", achievement.achievement_name, " (unlocked: ", is_unlocked, ")")
	
	print("Finished populating achievements. Total items created: ", achievements_container.get_child_count())

func _on_close_button_pressed() -> void:
	print("Close button pressed!")
	hide_achievements()
