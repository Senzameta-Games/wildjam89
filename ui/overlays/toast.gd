extends Control
class_name Toast

@onready var title: Label = $Container/Text/Title
@onready var description: Label = $Container/Text/Description
@onready var toast_sfx: AudioStreamPlayer2D = $SFX/AchievementGet

var tween: Tween
var _play_sfx: bool = true

func _ready() -> void:
	modulate.a = 0.0

func show_achievement(achievement: AchievementData) -> void:
	title.text = achievement.achievement_name
	description.text = achievement.achievement_description
	animate_in()

## Compact single-line toast for system notifications (save, load, etc.).
## Hides the description row and shrinks the minimum height.
func show_text(message: String) -> void:
	title.text = message
	description.visible = false
	custom_minimum_size.y = 30.0
	_play_sfx = false
	animate_in()

func animate_in() -> void:
	if tween:
		tween.kill()
	
	tween = create_tween()
	tween.set_parallel(true)
	
	# Slide in from left — .from() sets the start value explicitly so no
	# pre-positioning in _ready() is needed and there's no single-frame flash.
	tween.tween_property(self, "offset_left", 10.0, 0.5).from(-300.0).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	# Fade in from invisible
	tween.tween_property(self, "modulate:a", 1.0, 0.3).from(0.0).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	if _play_sfx:
		toast_sfx.play()
	
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
