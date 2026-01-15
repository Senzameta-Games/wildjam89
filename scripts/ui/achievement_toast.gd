extends Control
class_name AchievementToast

@onready var title: Label = $Container/Text/Title
@onready var description: Label = $Container/Text/Description

var tween: Tween

func _ready() -> void:
	# Wait for size to be calculated
	await get_tree().process_frame
	# Start off-screen
	offset_left = -size.x - 20
	modulate.a = 0.0

func show_achievement(achievement: AchievementData) -> void:
	# Set content
	title.text = achievement.achievement_name
	description.text = achievement.achievement_description
	
	# Animate in
	animate_in()

func animate_in() -> void:
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.set_parallel(true)
	
	# Slide in from left
	tween.tween_property(self, "offset_left", 10.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Fade in
	tween.tween_property(self, "modulate:a", 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	
	# Wait, then animate out
	await get_tree().create_timer(3.0).timeout
	animate_out()

func animate_out() -> void:
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.set_parallel(true)
	
	# Slide out to left
	tween.tween_property(self, "offset_left", -size.x - 20, 0.4).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	# Fade out
	tween.tween_property(self, "modulate:a", 0.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	
	# Remove after animation
	tween.tween_callback(queue_free)
