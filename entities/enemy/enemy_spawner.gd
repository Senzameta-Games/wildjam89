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

		var temp = enemy_scene.instantiate()
		var kind = temp.get("enemy_kind")
		temp.free()

		match kind:
			EnemyData.EnemyType.BIRD:
				bird_enemies.append(enemy_scene)
			EnemyData.EnemyType.BEETLE:
				beetle_enemies.append(enemy_scene)
			_:
				basic_enemies.append(enemy_scene)

func _on_timer_done() -> void:
	if enemies.is_empty():
		return
	
	var spawnable: Array[PackedScene] = []
	
	spawnable.append_array(basic_enemies)
	
	# Beetles after 1 tree
	if Session.trees_grown_count >= 1:
		spawnable.append_array(beetle_enemies)

	if Session.trees_grown_count >= 2:
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

## Spawn a single enemy of the given scene at the given position.
## Returns the spawned enemy instance, or null if spawning failed.
## The caller is responsible for any special configuration (no_aggro, freeze, etc).
func spawn_single(enemy_scene: PackedScene, spawn_position: Vector2) -> Enemy:
	if not enemy_scene:
		push_warning("EnemySpawner.spawn_single: No scene provided")
		return null
	var enemy = enemy_scene.instantiate() as Enemy
	if not enemy:
		push_warning("EnemySpawner.spawn_single: Scene did not produce an Enemy")
		return null
	enemy.global_position = spawn_position
	get_tree().current_scene.add_child(enemy)
	return enemy

## Spawn a single enemy by its EnemyData.EnemyType enum value.
## Uses the spawner's configured scene arrays. Returns null if the type isn't available.
func spawn_single_by_type(enemy_type: EnemyData.EnemyType, spawn_position: Vector2) -> Enemy:
	var candidates: Array[PackedScene]
	match enemy_type:
		EnemyData.EnemyType.BIRD:
			candidates = bird_enemies
		EnemyData.EnemyType.BEETLE:
			candidates = beetle_enemies
		_:
			candidates = basic_enemies
	if candidates.is_empty():
		push_warning("EnemySpawner.spawn_single_by_type: No scenes available for type %d" % enemy_type)
		return null
	return spawn_single(candidates[0], spawn_position)
