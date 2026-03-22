extends Node

# Tutorial overall flags
var tutorial_completed: bool = false
var tutorial_flags: Dictionary = {
	"tips_seen": false,
	"acorn_stomped": false,
	"snail_stomped": false
}

# Tutorial flags
var is_tutorial_active: bool = false
var current_tutorial_acorn: Node2D = null
var current_tutorial_snail: Node2D = null
var snail_move_timer: float = 0.0
var snail_stopped: bool = false

# Scene references
var tutorial_prompt_scene: PackedScene = preload("res://ui/tutorial/tutorial_prompt.tscn")
var tutorial_tips_scene: PackedScene = preload("res://ui/tutorial/tutorial_tips.tscn")

# Signals
signal tutorial_phase_completed(phase: String)
signal show_tutorial_prompt(target: Node2D, text: String)
signal hide_tutorial_prompt
signal show_tips_screen

func _process(delta: float) -> void:
	if is_tutorial_active and tutorial_flags["acorn_stomped"] and not tutorial_flags["snail_stomped"]:
		if current_tutorial_snail and is_instance_valid(current_tutorial_snail):
			if not snail_stopped:
				snail_move_timer += delta
				if snail_move_timer >= 3.5:
					_stop_tutorial_snail()

func start_tutorial() -> void:
	if tutorial_completed:
		return
	
	is_tutorial_active = true
	print("Tutorial started")
	
	_disable_spawners()
	
	# Show tips first, before anything else spawns
	_show_tips_screen()

func _disable_spawners() -> void:
	var spawners = get_tree().get_nodes_in_group("spawner")
	for spawner in spawners:
		spawner.set_process(false)
		if spawner.has_node("Timer"):
			var timer = spawner.get_node("Timer")
			timer.stop()

func _enable_spawners() -> void:
	var spawners = get_tree().get_nodes_in_group("spawner")
	for spawner in spawners:
		spawner.set_process(true)
		if spawner.has_node("Timer"):
			var timer = spawner.get_node("Timer")
			timer.start()

func _show_tips_screen() -> void:
	show_tips_screen.emit()
	await get_tree().create_timer(0.35).timeout
	get_tree().paused = true

# Called by TutorialTips when player clicks "Ciao!"
func on_tips_acknowledged() -> void:
	tutorial_flags["tips_seen"] = true
	tutorial_phase_completed.emit("tips_seen")
	get_tree().paused = false
	
	# Now spawn the player and acorn
	_wait_for_acorn_plant()

func _wait_for_acorn_plant() -> void:
	# Find the first acorn
	await get_tree().create_timer(0.5).timeout
	
	var acorns = get_tree().get_nodes_in_group("acorn")
	if acorns.is_empty():
		# Wait and try again
		await get_tree().create_timer(0.5).timeout
		_wait_for_acorn_plant()
		return
	
	current_tutorial_acorn = acorns[0]
	
	# Show prompt above acorn
	show_tutorial_prompt.emit(current_tutorial_acorn, "Stomp")
	
	# Wait for acorn to be stomped
	if current_tutorial_acorn.has_signal("planted"):
		await current_tutorial_acorn.planted
		_on_acorn_stomped()

func _on_acorn_stomped() -> void:
	tutorial_flags["acorn_stomped"] = true
	hide_tutorial_prompt.emit()
	tutorial_phase_completed.emit("acorn_stomped")
	print("Tutorial: Acorn stomped")
	
	_start_music()

	await get_tree().create_timer(0.3).timeout
	await get_tree().create_timer(0.5).timeout
	
	_spawn_tutorial_snail()

func _start_music() -> void:
	var level = get_tree().current_scene.find_child("Level", true, false)
	if level and level.has_node("Music"):
		var music = level.get_node("Music") as AudioStreamPlayer2D
		if music and not music.playing:
			music.play()
			print("Tutorial: Music started!")

func _spawn_tutorial_snail() -> void:
	var spawners = get_tree().get_nodes_in_group("spawner")
	if spawners.is_empty():
		print("Tutorial: No spawners found!")
		return
	
	var trees = get_tree().get_nodes_in_group("tree")
	if trees.is_empty():
		print("Tutorial: No tree found!")
		return
	
	var tree = trees[0]
	var tree_x = tree.global_position.x

	var furthest_spawner = null
	var max_distance = 0.0
	
	for spawner in spawners:
		var distance = abs(spawner.global_position.x - tree_x)
		if distance > max_distance:
			max_distance = distance
			furthest_spawner = spawner
	
	if not furthest_spawner:
		return

	# Spawn a snail (slow-strong enemy)
	var snail_scene = preload("res://entities/enemy/variants/slow-strong.tscn")
	var snail = snail_scene.instantiate()
	get_tree().current_scene.add_child(snail)
	snail.global_position = furthest_spawner.global_position
	
	# Make sure it targets the tree
	if snail.has_method("aggro_tree"):
		snail.call_deferred("aggro_tree")
	
	current_tutorial_snail = snail
	snail_move_timer = 0.0
	snail_stopped = false
	
	# Connect to snail's defeat signal
	if snail.has_signal("enemy_defeated"):
		snail.enemy_defeated.connect(_on_snail_stomped)

func _stop_tutorial_snail() -> void:
	if not current_tutorial_snail or not is_instance_valid(current_tutorial_snail):
		return
	
	snail_stopped = true

	current_tutorial_snail.set_physics_process(false)
	current_tutorial_snail.velocity = Vector2.ZERO

	if current_tutorial_snail.has_node("Sprite"):
		var sprite = current_tutorial_snail.get_node("Sprite")
		if sprite is AnimatedSprite2D:
			sprite.play("idle")

	await get_tree().create_timer(0.3).timeout

	show_tutorial_prompt.emit(current_tutorial_snail, "Stomp")

func _on_snail_stomped() -> void:
	tutorial_flags["snail_stomped"] = true
	hide_tutorial_prompt.emit()
	tutorial_phase_completed.emit("snail_stomped")
	print("Tutorial: Snail stomped - tutorial complete!")
	
	# Go straight into the game
	complete_tutorial()

func complete_tutorial() -> void:
	tutorial_completed = true
	is_tutorial_active = false
	_enable_spawners()
	Saves.write_meta()
	tutorial_phase_completed.emit("complete")

func serialize_meta() -> Dictionary:
	return { "tutorial_completed": tutorial_completed }

func deserialize_meta(data: Dictionary) -> void:
	tutorial_completed = data.get("tutorial_completed", false)

func reset_tutorial() -> void:
	tutorial_completed = false
	tutorial_flags = {
		"tips_seen": false,
		"acorn_stomped": false,
		"snail_stomped": false
	}
	is_tutorial_active = false
