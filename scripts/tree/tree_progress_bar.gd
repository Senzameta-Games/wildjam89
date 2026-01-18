extends Control

@onready var progress_bar: ProgressBar = $ProgressBar
@export var alert_sfx: AudioStream 

var tree: SeedTree
var audio_player: AudioStreamPlayer
var tween: Tween
var current_state: int = State.NORMAL

const LOW_HEALTH_LIMIT = 15.0

var default_fill_color: Color
var default_bg_color: Color

enum State {
	NORMAL,
	LOW_HEALTH,
	SUDDEN_DEATH
}

func _ready() -> void:
	tree = get_tree().get_first_node_in_group("tree")
	
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	if progress_bar.has_theme_stylebox("fill"):
		var fill_style = progress_bar.get_theme_stylebox("fill").duplicate()
		progress_bar.add_theme_stylebox_override("fill", fill_style)
		default_fill_color = fill_style.bg_color
	
	if progress_bar.has_theme_stylebox("background"):
		var bg_style = progress_bar.get_theme_stylebox("background").duplicate()
		progress_bar.add_theme_stylebox_override("background", bg_style)
		default_bg_color = bg_style.bg_color

func _process(_delta: float) -> void:
	if not is_instance_valid(tree): return
	
	progress_bar.value = tree.tree_progress
	
	var new_state = State.NORMAL
	
	if tree.sudden_death:
		new_state = State.SUDDEN_DEATH
	elif tree.tree_progress <= LOW_HEALTH_LIMIT and tree.tree_progress > 0.0:
		new_state = State.LOW_HEALTH

	if new_state != current_state:
		_change_state(new_state)

func _change_state(new_state: int) -> void:
	current_state = new_state
	if tween: tween.kill()
	_reset_colors()
	
	match current_state:
		State.NORMAL:
			pass
			
		#State.LOW_HEALTH:
			#_start_low_health_fx()
			
		State.SUDDEN_DEATH:
			_start_sudden_death_fx()

func _reset_colors() -> void:
	if progress_bar.has_theme_stylebox("fill"):
		var sb = progress_bar.get_theme_stylebox("fill") as StyleBoxFlat
		if sb: sb.bg_color = default_fill_color
		
	if progress_bar.has_theme_stylebox("background"):
		var sb = progress_bar.get_theme_stylebox("background") as StyleBoxFlat
		if sb: sb.bg_color = default_bg_color

#func _start_low_health_fx() -> void:
	#if progress_bar.has_theme_stylebox("fill"):
		#var sb = progress_bar.get_theme_stylebox("fill") as StyleBoxFlat
		#if sb:
			#tween = create_tween().set_loops()
			#tween.tween_property(sb, "bg_color", Color.RED, 0.0)
			#tween.tween_property(sb, "bg_color", default_fill_color, 0.63)
#
	#_play_alarm_sequence(1.0)

func _start_sudden_death_fx() -> void:
	if progress_bar.has_theme_stylebox("background"):
		var sb = progress_bar.get_theme_stylebox("background") as StyleBoxFlat
		if sb:
			tween = create_tween().set_loops()
			tween.tween_property(sb, "bg_color", Color(0.2, 0, 0), 0)
			tween.tween_property(sb, "bg_color", default_bg_color, 0.63)
	_play_alarm_sequence(1.5)

func _play_alarm_sequence(pitch: float) -> void:
	if not alert_sfx: return
	
	audio_player.stream = alert_sfx
	audio_player.volume_db = -12.0
	audio_player.pitch_scale = pitch
	for i in range(3):
		audio_player.play()
		await audio_player.finished
		if i < 2: await get_tree().create_timer(0.1).timeout
