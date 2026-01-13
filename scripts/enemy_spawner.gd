extends Node2D
class_name EnemySpawner

@export var enemy_scene: PackedScene

func _ready() -> void:
	$Timer.timeout.connect(_on_timer_done)

func _on_timer_done() -> void:
	if enemy_scene == null:
		return
	
	var enemy = enemy_scene.instantiate()
	
	enemy.global_position = global_position
	
	get_parent().add_child(enemy)
