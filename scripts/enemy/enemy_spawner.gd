extends Node2D
class_name EnemySpawner

@export var enemies: Array[PackedScene]
@export var timer_interval: float = 5.0

var spawn_passive: bool = false

@onready var timer: Timer = $Timer

func _ready() -> void:
	add_to_group("spawner")
	timer.wait_time = timer_interval
	timer.timeout.connect(_on_timer_done)
	timer.start()

func _on_timer_done() -> void:
	if enemies.is_empty():
		return
	var rand_enemy = enemies.pick_random()
	_spawn_enemy(rand_enemy)

func _spawn_enemy(scene: PackedScene) -> void:
	var enemy = scene.instantiate()
	enemy.global_position = global_position
	get_parent().add_child(enemy)
	
	# NEW: Apply passive behavior if flag is set
	if spawn_passive and enemy.has_method("no_aggro"):
		enemy.no_aggro()
	elif not spawn_passive and enemy.has_method("aggro_tree"):
		# Default behavior
		enemy.aggro_tree()
