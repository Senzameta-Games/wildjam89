extends Node

# Music fade settings
var fade_duration: float = 0.2
var paused_pitch: float = 0.5
var current_music_player: AudioStreamPlayer2D = null
var current_tween: Tween = null

func _ready() -> void:
	call_deferred("_find_music_player")

func _find_music_player() -> void:
	var level = get_tree().current_scene.find_child("Level", true, false)
	if level:
		current_music_player = level.find_child("Music", true, false)

func _start_pitch_tween(target_pitch: float) -> void:
	if not current_music_player:
		return

	if current_tween and current_tween.is_valid():
		current_tween.kill()
	
	current_tween = create_tween()
	current_tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	current_tween.tween_property(current_music_player, "pitch_scale", target_pitch, fade_duration)

func fade_to_paused() -> void:
	_start_pitch_tween(paused_pitch)

func fade_to_normal() -> void:
	_start_pitch_tween(1.0)

func fade_to_aim_slowmo() -> void:
	_start_pitch_tween(0.25)

func refresh_music_player() -> void:
	_find_music_player()
