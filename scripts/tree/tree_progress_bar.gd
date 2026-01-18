extends Control

@onready var progress_bar: ProgressBar = $ProgressBar
@export var alert_sfx: AudioStream 

var audio_player: AudioStreamPlayer
var tween: Tween
var current_state: int = State.NORMAL

# If this is set (or found), we only track this tree.
var specific_tree: SeedTree 

#const LOW_HEALTH_LIMIT = 15.0
var default_fill_color: Color
var default_bg_color: Color

enum State {
	NORMAL,
	#LOW_HEALTH,
	SUDDEN_DEATH
}

func _ready() -> void:
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	
	# Setup visual defaults
	if progress_bar.has_theme_stylebox("fill"):
		var fill_style = progress_bar.get_theme_stylebox("fill").duplicate()
		progress_bar.add_theme_stylebox_override("fill", fill_style)
		default_fill_color = fill_style.bg_color
	
	if progress_bar.has_theme_stylebox("background"):
		var bg_style = progress_bar.get_theme_stylebox("background").duplicate()
		progress_bar.add_theme_stylebox_override("background", bg_style)
		default_bg_color = bg_style.bg_color

	# SMART DISCOVERY:
	# If our 'owner' is a SeedTree (we are inside the Tree prefab), track ONLY that tree.
	if owner is SeedTree:
		specific_tree = owner
	else:
		# Fallback: We might be part of the Level UI, so we track global progress (optional)
		pass

func _process(_delta: float) -> void:
	var target_val: float = 0.0
	var is_sudden_death: bool = false
	
	# MODE A: Specific Tree (Local UI)
	if is_instance_valid(specific_tree):
		target_val = specific_tree.tree_progress
		is_sudden_death = specific_tree.sudden_death
		
	# MODE B: Global Average (Level UI fallback)
	else:
		var trees = get_tree().get_nodes_in_group("tree")
		if not trees.is_empty():
			var total_progress: float = 0.0
			for t in trees:
				if t is SeedTree:
					total_progress += t.tree_progress
					if t.sudden_death:
						is_sudden_death = true
			target_val = total_progress / float(trees.size())
	
	# Apply Value
	progress_bar.value = target_val
	
	# Determine State
	var new_state = State.NORMAL
	
	if is_sudden_death:
		new_state = State.SUDDEN_DEATH
	#elif target_val <= LOW_HEALTH_LIMIT and target_val > 0.0:
		#new_state = State.LOW_HEALTH
		
	if new_state != current_state:
		_change_state(new_state)

func _change_state(new_state: int) -> void:
	current_state = new_state
	if tween: tween.kill()
	_reset_colors()
	
	match current_state:
		State.NORMAL: pass
		#State.LOW_HEALTH: _start_low_health_fx()
		State.SUDDEN_DEATH: _start_sudden_death_fx()

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
			#tween.tween_property(sb, "bg_color", Color.RED, 0.5)
			#tween.tween_property(sb, "bg_color", default_fill_color, 0.5)
	
	# Only play sound if this is the active tree being interacted with to avoid cacophony?
	# Or keep it as a warning.
	_play_alarm_sequence(1.0)

func _start_sudden_death_fx() -> void:
	if progress_bar.has_theme_stylebox("background"):
		var sb = progress_bar.get_theme_stylebox("background") as StyleBoxFlat
		if sb:
			tween = create_tween().set_loops()
			tween.tween_property(sb, "bg_color", Color.RED, 0.5)
			tween.tween_property(sb, "bg_color", Color.WHITE, 0.5)
	_play_alarm_sequence(1.5)

func _play_alarm_sequence(pitch: float) -> void:
	if not alert_sfx: return
	audio_player.stream = alert_sfx
	audio_player.pitch_scale = pitch
	for i in range(3):
		audio_player.play()
		await audio_player.finished
		if i < 2: await get_tree().create_timer(0.1).timeout
