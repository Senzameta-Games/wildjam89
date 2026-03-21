extends Node2D

signal goal_reached

@onready var sfx_collect: AudioStreamPlayer2D = $SFX/Collect
@onready var goal_sprite: Sprite2D = $Sprite

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _on_hitbox_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		$Hitbox/Collider.set_deferred("disabled", true)

		if goal_sprite:
			goal_sprite.visible = false
		goal_reached.emit()

		if sfx_collect:
			sfx_collect.play()
			await sfx_collect.finished

		queue_free()
