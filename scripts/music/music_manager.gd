extends Node

# Music fade settings
var fade_duration: float = 0.2
var paused_pitch: float = 0.5

var is_fading: bool = false
var current_music_player: AudioStreamPlayer2D = null

func _ready() -> void:
	# Find the music player in the scene
	call_deferred("_find_music_player")

func _find_music_player() -> void:
	# Try to find the music player in the level
	var level = get_tree().current_scene.find_child("Level", true, false)
	if level:
		current_music_player = level.find_child("Music", true, false)
		#if current_music_player:
			#print("found music player")

func fade_to_paused() -> void:
	if not current_music_player:
		#print("no music player found for fade_to_paused")
		return
	
	if is_fading:
		#print("already fading")
		return
	
	is_fading = true
	var tween = create_tween()
	tween.tween_property(current_music_player, "pitch_scale", paused_pitch, fade_duration)
	tween.tween_callback(func(): is_fading = false)

func fade_to_normal() -> void:
	if not current_music_player:

		return
	
	if is_fading:
		return
	
	is_fading = true
	var tween = create_tween()
	tween.set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(current_music_player, "pitch_scale", 1.0, fade_duration)
	tween.tween_callback(func(): is_fading = false)

func refresh_music_player() -> void:
	_find_music_player()
