class_name RunRoom
extends Node2D
## Base class for hand-designed run rooms.
## Default behavior: room clears when all nodes in the "enemy" group are defeated.
## Override _on_exit_condition_met() for non-combat exit conditions.
##
## Doors: any DoorTrigger child of the Doors node is auto-connected in _ready().
##   - A door named "To_Grove" triggers a return to grove (to_grove = true).
##   - All other doors advance to the next room, passing entry_door_in_destination
##     so RunManager can position the player at the correct spawn.

signal room_cleared
signal room_exit_requested(entry_door_name: String, to_grove: bool)

func _ready() -> void:
	_connect_enemies()
	_connect_doors()

func _connect_enemies() -> void:
	for enemy: Node in get_tree().get_nodes_in_group("enemy"):
		if enemy.has_signal("enemy_defeated"):
			enemy.enemy_defeated.connect(_on_enemy_defeated)

func _connect_doors() -> void:
	var doors: Node = get_node_or_null("Doors")
	if doors == null:
		return
	for door: Node in doors.get_children():
		if door.has_signal("door_activated"):
			door.door_activated.connect(_on_door_activated)

func _on_door_activated(door: DoorTrigger) -> void:
	var to_grove: bool = door.name == "To_Grove"
	room_exit_requested.emit(door.entry_door_in_destination, to_grove)

func _on_enemy_defeated() -> void:
	await get_tree().process_frame
	if get_tree().get_nodes_in_group("enemy").is_empty():
		_on_exit_condition_met()

func _on_exit_condition_met() -> void:
	room_cleared.emit()
