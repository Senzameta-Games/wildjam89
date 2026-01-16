extends Node2D

signal goal_reached

@onready var sfx_collect: AudioStreamPlayer2D = $SFX/Collect

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if body.get("is_stomping"):
			_trigger_goal_collect(body)

func _trigger_goal_collect(body: Node2D) -> void:
	if body.has_method("bounce"):
		body.bounce()
		
	if sfx_collect:
		sfx_collect.play()
		
	goal_reached.emit()
	
	$Hitbox/Collider.set_deferred("disabled", true)
	queue_free()
