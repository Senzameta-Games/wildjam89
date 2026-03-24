class_name DoorTrigger
extends Area2D
## Attach to any door Area2D. Emits door_activated when a Player body enters.
## Set entry_door_in_destination to the name of the receiving door in the
## destination room — RunManager uses it to position the player at that door's
## EnterSpawn marker.

signal door_activated(door: DoorTrigger)

## Name of the door in the destination scene whose EnterSpawn the player
## should use. Leave empty to use the destination's default spawn.
@export var entry_door_in_destination: String = ""

@onready var enter_spawn: Marker2D = $EnterSpawn

var _suppress_next_entry: bool = false

func _ready() -> void:
	set_collision_mask_value(2, true)  # player physics layer
	body_entered.connect(_on_body_entered)

## Call this before positioning the player inside this area so the
## resulting body_entered is silently consumed rather than triggering a
## transition. The door becomes fully live again on the next entry.
func suppress_next_entry() -> void:
	_suppress_next_entry = true

func _on_body_entered(body: Node2D) -> void:
	if not body is Player:
		return
	if _suppress_next_entry:
		_suppress_next_entry = false
		return
	set_deferred("monitoring", false)
	door_activated.emit(self)
