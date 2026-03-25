class_name RoomArea
extends Area2D

signal player_entered(room: RoomArea)
signal player_exited(room: RoomArea)
signal room_cleared(room: RoomArea)
signal state_changed(room: RoomArea, new_state: StringName)

@export var data: RoomData

var room_state: StringName

var _player_inside: bool = false

func _ready() -> void:
	collision_layer = 0
	collision_mask = 0
	set_collision_mask_value(2, true)
	if data:
		room_state = data.initial_state
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

func get_bounds() -> Rect2:
	for child: Node in get_children():
		var shape_node := child as CollisionShape2D
		if shape_node == null:
			continue
		var rect_shape := shape_node.shape as RectangleShape2D
		if rect_shape == null:
			continue
		var half_size: Vector2 = rect_shape.size / 2.0
		return Rect2(shape_node.global_position - half_size, rect_shape.size)
	return Rect2(global_position - Vector2(320.0, 180.0), Vector2(640.0, 360.0))

func clear_room() -> void:
	room_state = &"cleared"
	room_cleared.emit(self)

func set_state(new_state: StringName) -> void:
	room_state = new_state
	state_changed.emit(self, new_state)

func _on_body_entered(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	_player_inside = true
	player_entered.emit(self)

func _on_body_exited(body: Node2D) -> void:
	if not body.is_in_group(&"player"):
		return
	_player_inside = false
	player_exited.emit(self)
