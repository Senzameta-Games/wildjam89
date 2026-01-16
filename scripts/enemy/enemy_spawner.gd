extends Node2D
class_name EnemySpawner

@export var enemies: Array[PackedScene]

func _ready() -> void:
	$Timer.timeout.connect(_on_timer_done)

func _on_timer_done() -> void:
	if enemies.is_empty():
		return
	var rand_enemy = enemies.pick_random()
	_spawn_enemy(rand_enemy)

func _spawn_enemy(scene: PackedScene) -> void:
	var enemy = scene.instantiate()
	enemy.global_position = global_position
	get_parent().add_child(enemy)
