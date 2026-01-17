extends Node2D

func _on_area_entered(area: Area2D) -> void:
	var body = area.get_parent()
	if body is Player and body.is_stomping:
		_activate()

func _on_body_entered(body: Node2D) -> void:
	if body is Player and body.is_stomping:
		_activate()

func _activate() -> void:
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 0.1), 0.1)
	tween.tween_callback(func(): Game.next_stage())
