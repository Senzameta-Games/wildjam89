extends Node2D

func _ready() -> void:
	$Area.body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		_activate()

func _activate() -> void:
	$Area/Collider.set_deferred("disabled", true)
	
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(1.2, 0.1), 0.1)
	tween.tween_callback(func(): Session.next_stage())
