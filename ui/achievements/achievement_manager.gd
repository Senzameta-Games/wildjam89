extends Control
class_name AchievementManager

# Manages the display of achievement toasts
# Should be added to the CanvasLayer in main.tscn

var toast_scene: PackedScene = preload("res://scenes/ui/achievement_toast.tscn")
var toast_queue: Array[AchievementData] = []
var is_showing_toast: bool = false

@onready var toast_container: VBoxContainer = $ToastContainer

func _ready() -> void:
	# Connect to achievement system
	if Achievements:
		Achievements.achievement_unlocked.connect(_on_achievement_unlocked)

func _on_achievement_unlocked(achievement: AchievementData) -> void:
	show_toast(achievement)

func show_toast(achievement: AchievementData) -> void:
	if is_showing_toast:
		# Queue the toast if one is already showing
		toast_queue.append(achievement)
		return
	
	# Create and show toast
	var toast = toast_scene.instantiate() as AchievementToast
	toast_container.add_child(toast)
	is_showing_toast = true
	
	toast.show_achievement(achievement)
	
	# Wait for toast to finish, then show next in queue
	await get_tree().create_timer(3.5).timeout
	is_showing_toast = false
	
	# Show next toast if any
	if toast_queue.size() > 0:
		var next_achievement = toast_queue.pop_front()
		show_toast(next_achievement)
