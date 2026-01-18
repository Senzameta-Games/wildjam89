extends Node2D
class_name EnemySpawner

@export var enemies: Array[PackedScene]
@export var timer_interval: float = 4.0

var spawn_passive: bool = false

@onready var timer: Timer = $Timer

# Separate enemy types for conditional spawning
var basic_enemies: Array[PackedScene] = []
var beetle_enemies: Array[PackedScene] = []
var bird_enemies: Array[PackedScene] = []


const MAX_BIRDS: int = 3 # Maximum number of birds allowed at once

func _ready() -> void:
	add_to_group("spawner")
	timer.wait_time = timer_interval
	timer.timeout.connect(_on_timer_done)
	timer.start()
	
	_categorize_enemies()

func _categorize_enemies() -> void:
	for enemy_scene in enemies:
		if enemy_scene == null:
			continue

		var path = enemy_scene.resource_path.to_lower()
		
		if "bird" in path:
			bird_enemies.append(enemy_scene)
		elif "bomb-thrower" in path or "beetle" in path:
			beetle_enemies.append(enemy_scene)
		else:
			basic_enemies.append(enemy_scene)

func _on_timer_done() -> void:
	if enemies.is_empty():
		return
	
	var spawnable: Array[PackedScene] = []
	
	spawnable.append_array(basic_enemies)
	
	# Beetles after 1 tree
	if Game.trees_grown_count >= 1:
		spawnable.append_array(beetle_enemies)
	
	if Game.trees_grown_count >= 2:
		# Count existing birds
		var current_birds = 0
		var active_enemies = get_tree().get_nodes_in_group("enemy")
		for e in active_enemies:
			if e is Bird:
				current_birds += 1
		
		if current_birds < MAX_BIRDS:
			spawnable.append_array(bird_enemies)
	
	if spawnable.is_empty():
		return
	
	var rand_enemy = spawnable.pick_random()
	_spawn_enemy(rand_enemy)

func _spawn_enemy(scene: PackedScene) -> void:
	var enemy = scene.instantiate()
	enemy.global_position = global_position
	get_parent().add_child(enemy)
	
	if spawn_passive and enemy.has_method("no_aggro"):
		enemy.no_aggro()
	elif not spawn_passive and enemy.has_method("aggro_tree"):
		# Default behavior
		enemy.aggro_tree()

# Called by level to update spawn rate based on difficulty
func set_spawn_interval(new_interval: float) -> void:
	timer_interval = new_interval
	timer.wait_time = new_interval
