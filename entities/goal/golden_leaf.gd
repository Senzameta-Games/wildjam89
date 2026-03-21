extends Marker2D

signal goal_reached

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var sfx_collect: AudioStreamPlayer2D = $SFX/Collect
@onready var hitbox_collider: CollisionShape2D = $Hitbox/Collider

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	
	# Floating animation
	if sprite:
		var start_y = sprite.position.y
		var tween = create_tween().set_loops()
		tween.tween_property(sprite, "position:y", start_y - 4.0, 1.0).set_trans(Tween.TRANS_SINE)
		tween.tween_property(sprite, "position:y", start_y + 4.0, 1.0).set_trans(Tween.TRANS_SINE)

# This function should be connected to the 'body_entered' signal of the "Hitbox" child node
func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		if hitbox_collider:
			hitbox_collider.set_deferred("disabled", true)
		
		if sprite:
			sprite.visible = false
		
		# Trigger Win Condition
		Session.win_game()
		
		goal_reached.emit()
		
		if sfx_collect:
			sfx_collect.play()
			await sfx_collect.finished
			
		queue_free()
