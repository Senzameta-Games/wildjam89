class_name RunRoom
extends Node2D
## Base class for hand-designed run rooms.
## Default behavior: room clears when all nodes in the "enemy" group are defeated.
## Override _on_exit_condition_met() for non-combat exit conditions.

signal room_cleared

func _ready() -> void:
	_connect_enemies()

func _connect_enemies() -> void:
	for enemy: Node in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_signal("enemy_defeated"):
			enemy.enemy_defeated.connect(_on_enemy_defeated)

func _on_enemy_defeated() -> void:
	await get_tree().process_frame
	if get_tree().get_nodes_in_group("enemy").is_empty():
		_on_exit_condition_met()

func _on_exit_condition_met() -> void:
	room_cleared.emit()
